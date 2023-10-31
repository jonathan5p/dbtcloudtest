data "aws_ssm_parameter" "ds_clean_library_version" {
  name = "/parameter/${var.site}/${var.environment}/codebuild/bright_clean_version"
}

data "aws_ssm_parameter" "bright_pypi_pipconf" {
  name = "/secure/${var.site}/${var.environment_devops}/codebuild/bright_pypi_pipconf"
}

locals {
  parameter_path        = "parameter/${var.site}/${var.environment}/geosvc/api_uri"
  ind_dedup_job_workers = 20
  org_dedup_job_workers = 30
  counties_path         = "s3://${var.project_objects.data_bucket_id}/raw_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/native_counties/RulesToDetermineNativeRecords.csv"
  jfrog_url             = "--${trimspace(replace(replace(data.aws_ssm_parameter.bright_pypi_pipconf.value, "[global]", ""), " ", ""))}"
}

#------------------------------------------------------------------------------
# Upload S3 Data
#------------------------------------------------------------------------------

resource "aws_s3_object" "glue_jars" {
  bucket                 = var.project_objects.glue_bucket_id
  for_each               = fileset("../src/mainprocess/glue/jars", "**")
  key                    = join("/", ["jars", each.value])
  source                 = "../src/mainprocess/glue/jars/${each.value}"
  server_side_encryption = "AES256"
  bucket_key_enabled     = true
}

#------------------------------------------------------------------------------
# Glue DB
#------------------------------------------------------------------------------

module "glue_db_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "oidhdb"])
}

resource "aws_glue_catalog_database" "dedup_process_glue_db" {
  name         = module.glue_db_naming.name
  location_uri = "s3://${var.project_objects.data_bucket_id}/"
  tags         = module.glue_db_naming.tags
}

module "glue_alayasyncdb_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "alayasync"])
}

resource "aws_glue_catalog_database" "alayasync_process_glue_db" {
  name         = module.glue_alayasyncdb_naming.name
  location_uri = "s3://${var.project_objects.data_bucket_id}/consume_data/${module.glue_alayasyncdb_naming.name}"
  tags         = module.glue_alayasyncdb_naming.tags
}

#------------------------------------------------------------------------------
# Glue Security Configuration
#------------------------------------------------------------------------------

module "glue_secconfig_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gls"
  purpose     = join("", [var.project_prefix, "-", "securityconfig"])
}

resource "aws_glue_security_configuration" "glue_security_config" {
  name = module.glue_secconfig_naming.name
  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = var.project_objects.glue_enc_key
    }
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = var.project_objects.glue_enc_key
    }
    s3_encryption {
      s3_encryption_mode = "SSE-S3"
    }
  }
}

#------------------------------------------------------------------------------
# Redshift Credentials
#------------------------------------------------------------------------------

data "aws_ssm_parameter" "redshift_conn_username" {
  name = "/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift/username"
}

data "aws_ssm_parameter" "redshift_conn_password" {
  name = "/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift/password"
}

data "aws_ssm_parameter" "redshift_conn_jdbc_url" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/jdbc_url"
}

data "aws_ssm_parameter" "redshift_conn_subnetid" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/subnetid"
}

data "aws_ssm_parameter" "redshift_conn_securitygroupid" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/securitygroupid"
}

#------------------------------------------------------------------------------
# Glue Redshift Connection
#------------------------------------------------------------------------------

module "redshift_connection" {
  source                 = "../../../modules/glue_connection"
  base_naming            = var.base_naming
  project_prefix         = var.project_prefix
  conn_name              = "redshiftconn"
  password               = data.aws_ssm_parameter.redshift_conn_password.value
  username               = data.aws_ssm_parameter.redshift_conn_username.value
  jdbc_url               = data.aws_ssm_parameter.redshift_conn_jdbc_url.value
  subnet_id              = data.aws_ssm_parameter.redshift_conn_subnetid.value
  security_group_id_list = [data.aws_ssm_parameter.redshift_conn_securitygroupid.value]
}

#------------------------------------------------------------------------------
# Aurora Credentials
#------------------------------------------------------------------------------

data "aws_ssm_parameter" "aurora_conn_username" {
  name = "/secure/${var.site}/${var.environment}/${var.project_app_group}/aurora/username"
}

data "aws_ssm_parameter" "aurora_conn_password" {
  name = "/secure/${var.site}/${var.environment}/${var.project_app_group}/aurora/password"
}

#------------------------------------------------------------------------------
# Glue Aurora Connection
#------------------------------------------------------------------------------

module "aurora_connection" {
  source         = "../../../modules/glue_connection"
  base_naming    = var.base_naming
  project_prefix = var.project_prefix
  conn_name      = "auroraconn"
  password       = data.aws_ssm_parameter.aurora_conn_password.value
  username       = data.aws_ssm_parameter.aurora_conn_username.value
  jdbc_url       = var.project_objects.aurora_jdbc_url
  subnet_id      = var.project_objects.aurora_subnetid
}

#------------------------------------------------------------------------------
# Glue Ingest Job
#------------------------------------------------------------------------------

module "ingest_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=v0.1.0"
  base_naming         = var.base_naming
  project_prefix      = var.project_prefix
  max_concurrent_runs = 4
  timeout             = 60
  worker_type         = "G.1X"
  number_of_workers   = 4
  retry_max_attempts  = 0
  retry_interval      = 2
  retry_backoff_rate  = 2
  security_config_id  = aws_glue_security_configuration.glue_security_config.id
  connections         = [module.redshift_connection.conn_name]
  glue_path           = "../src/mainprocess/glue/"
  job_name            = "ingestjob"
  script_bucket       = var.project_objects.glue_bucket_id
  policy_variables    = var.project_objects
  job_arguments = {
    "--conf" = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"
    "--extra-jars" = join(",", ["s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["delta-core_2.12-2.3.0.jar"].id}",
    "s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["delta-storage-2.3.0.jar"].id}"])
    "--extra-py-files"      = "s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["delta-core_2.12-2.3.0.jar"].id}"
    "--job-bookmark-option" = "job-bookmark-disable"
    "--TempDir"             = "s3://${var.project_objects.glue_bucket_id}/tmp/"
  }
}

#------------------------------------------------------------------------------
# Glue GeoSvc Network Connection
#------------------------------------------------------------------------------

module "geosvc_connection" {
  source          = "../../../modules/glue_connection"
  connection_type = "NETWORK"
  base_naming     = var.base_naming
  project_prefix  = var.project_prefix
  conn_name       = "geosvcconn"
  subnet_id       = var.project_objects.glue_geosvc_subnetid
}

#------------------------------------------------------------------------------
# Glue Get Geo Info Job
#------------------------------------------------------------------------------

module "geo_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=develop"
  base_naming         = var.base_naming
  project_prefix      = var.project_prefix
  max_concurrent_runs = 4
  timeout             = 60
  worker_type         = "G.1X"
  number_of_workers   = 21
  security_config_id  = aws_glue_security_configuration.glue_security_config.id
  glue_path           = "../src/mainprocess/glue"
  job_name            = "getgeoinfojob"
  script_bucket       = var.project_objects.glue_bucket_id
  policy_variables    = merge(var.project_objects, { "parameter_name" = local.parameter_path })
  connections         = [module.geosvc_connection.conn_name]
  job_arguments = {
    "--data_bucket"       = var.project_objects.data_bucket_id
    "--geo_api_parameter" = "parameter/${var.site}/${var.environment}/geosvc/api_uri"
    "--conf"              = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"
    "--extra-jars" = join(",", ["s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["delta-core_2.12-2.3.0.jar"].id}",
    "s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["delta-storage-2.3.0.jar"].id}"])
    "--extra-py-files"      = "s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["delta-core_2.12-2.3.0.jar"].id}"
    "--job-bookmark-option" = "job-bookmark-disable"
    "--TempDir"             = "s3://${var.project_objects.glue_bucket_id}/tmp/"
  }
}

#------------------------------------------------------------------------------
# Glue Cleaning Job
#------------------------------------------------------------------------------

module "cleaning_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=v0.1.0"
  base_naming         = var.base_naming
  project_prefix      = var.project_prefix
  max_concurrent_runs = 1
  timeout             = 60
  worker_type         = "G.1X"
  number_of_workers   = 10
  retry_max_attempts  = 0
  retry_interval      = 2
  retry_backoff_rate  = 2
  security_config_id  = aws_glue_security_configuration.glue_security_config.id
  glue_path           = "../src/mainprocess/glue"
  job_name            = "cleaningjob"
  script_bucket       = var.project_objects.glue_bucket_id
  policy_variables    = var.project_objects

  job_arguments = {
    "--conf"                            = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"
    "--job-bookmark-option"             = "job-bookmark-disable"
    "--config_bucket"                   = var.project_objects.artifacts_bucket_id
    "--data_bucket"                     = var.project_objects.data_bucket_id
    "--agent_table_name"                = "bright_raw_agent_latest"
    "--office_table_name"               = "bright_staging_office_latest"
    "--team_table_name"                 = "bright_raw_team_latest"
    "--datalake-formats"                = "delta"
    "--python-modules-installer-option" = local.jfrog_url
    "--TempDir"                         = "s3://${var.project_objects.glue_bucket_id}/tmp/"
    "--glue_db"                         = aws_glue_catalog_database.dedup_process_glue_db.name
    "--model_version"                   = "1"
    "--additional-python-modules"       = "clean==${data.aws_ssm_parameter.ds_clean_library_version.value}"
  }
}

#------------------------------------------------------------------------------
# Glue Splink Individuals Job
#------------------------------------------------------------------------------

module "ind_dedup_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=v0.1.0"
  base_naming         = var.base_naming
  project_prefix      = var.project_prefix
  max_concurrent_runs = 1
  timeout             = 60
  worker_type         = "G.1X"
  number_of_workers   = local.ind_dedup_job_workers + 1
  retry_max_attempts  = 0
  retry_interval      = 2
  retry_backoff_rate  = 2
  security_config_id  = aws_glue_security_configuration.glue_security_config.id
  connections         = [module.aurora_connection.conn_name]
  glue_path           = "../src/mainprocess/glue"
  job_name            = "inddedupjob"
  script_bucket       = var.project_objects.glue_bucket_id
  policy_variables    = var.project_objects
  job_arguments = {
    "--conf"                      = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog --conf spark.default.parallelism=${local.ind_dedup_job_workers * 4 * 5} --conf spark.sql.shuffle.partitions=${local.ind_dedup_job_workers * 4 * 5}"
    "--extra-jars"                = "s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["scala-udf-similarity-0.1.1_spark3.x.jar"].id}"
    "--job-bookmark-option"       = "job-bookmark-disable"
    "--config_bucket"             = var.project_objects.artifacts_bucket_id
    "--data_bucket"               = var.project_objects.data_bucket_id
    "--agent_table_name"          = "clean_splink_agent_data"
    "--office_table_name"         = "clean_splink_office_data"
    "--TempDir"                   = "s3://${var.project_objects.glue_bucket_id}/tmp/"
    "--ssm_params_base"           = "${var.site}/${var.environment}/${var.project_prefix}/aurora"
    "--county_info_s3_path"       = local.counties_path
    "--max_records_per_file"      = var.project_objects.max_records_per_file
    "--model_version"             = 1
    "--datalake-formats"          = "delta"
    "--alaya_glue_db"             = aws_glue_catalog_database.alayasync_process_glue_db.name
    "--glue_db"                   = aws_glue_catalog_database.dedup_process_glue_db.name
    "--additional-python-modules" = "splink==3.9.2"
    "--aurora_table"              = "public.individuals"
    "--aurora_connection_name"    = module.aurora_connection.conn_name
    "--alaya_trigger_key"         = var.project_objects.alaya_trigger_key
  }
}

#------------------------------------------------------------------------------
# Glue Splink Organizations Job
#------------------------------------------------------------------------------

module "org_dedup_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=v0.1.0"
  base_naming         = var.base_naming
  project_prefix      = var.project_prefix
  max_concurrent_runs = 1
  timeout             = 60
  worker_type         = "G.1X"
  number_of_workers   = local.org_dedup_job_workers + 1
  retry_max_attempts  = 0
  retry_interval      = 2
  retry_backoff_rate  = 2
  security_config_id  = aws_glue_security_configuration.glue_security_config.id
  connections         = [module.aurora_connection.conn_name]
  glue_path           = "../src/mainprocess/glue"
  job_name            = "orgdedupjob"
  script_bucket       = var.project_objects.glue_bucket_id
  policy_variables    = var.project_objects
  job_arguments = {
    "--conf"                      = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog --conf spark.default.parallelism=${local.org_dedup_job_workers * 4 * 5} --conf spark.sql.shuffle.partitions=${local.org_dedup_job_workers * 4 * 5}"
    "--extra-jars"                = "s3://${var.project_objects.glue_bucket_id}/${aws_s3_object.glue_jars["scala-udf-similarity-0.1.1_spark3.x.jar"].id}"
    "--job-bookmark-option"       = "job-bookmark-disable"
    "--config_bucket"             = var.project_objects.artifacts_bucket_id
    "--data_bucket"               = var.project_objects.data_bucket_id
    "--office_table_name"         = "clean_splink_office_data"
    "--team_table_name"           = "clean_splink_team_data"
    "--TempDir"                   = "s3://${var.project_objects.glue_bucket_id}/tmp/"
    "--ssm_params_base"           = "${var.site}/${var.environment}/${var.project_prefix}/aurora"
    "--county_info_s3_path"       = local.counties_path
    "--max_records_per_file"      = var.project_objects.max_records_per_file
    "--model_version"             = 1
    "--datalake-formats"          = "delta"
    "--alaya_glue_db"             = aws_glue_catalog_database.alayasync_process_glue_db.name
    "--glue_db"                   = aws_glue_catalog_database.dedup_process_glue_db.name
    "--additional-python-modules" = "splink==3.9.2"
    "--aurora_table"              = "public.organizations"
    "--aurora_connection_name"    = module.aurora_connection.conn_name
    "--alaya_trigger_key"         = var.project_objects.alaya_trigger_key
  }
}
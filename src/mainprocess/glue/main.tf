#------------------------------------------------------------------------------
# Upload S3 Data
#------------------------------------------------------------------------------

resource "aws_s3_object" "glue_jars" {
  bucket                 = var.project_objects.glue_bucket_id
  for_each               = fileset("../src/mainprocess/glue/jars", "**")
  key                    = join("/", ["jars", each.value])
  source                 = "../src/mainprocess/glue/jars/${each.value}"
  server_side_encryption = "AES256"
  etag                   = filemd5("../src/mainprocess/glue/jars/${each.value}")
  bucket_key_enabled     = true
}

#------------------------------------------------------------------------------
# Glue DB
#------------------------------------------------------------------------------

module "glue_db_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "gluedb"])
}

resource "aws_glue_catalog_database" "dedup_process_glue_db" {
  name         = module.glue_db_naming.name
  location_uri = "s3://${var.project_objects.data_bucket_id}/"
  tags         = module.glue_db_naming.tags
}

#------------------------------------------------------------------------------
# Glue Security Configuration
#------------------------------------------------------------------------------

module "glue_secconfig_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gls"
  purpose     = join("", [var.project_prefix, "-", "gluesecurityconfig"])
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

data "aws_ssm_parameter" "aurora_conn_jdbc_url" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/aurora/jdbc_url"
}

data "aws_ssm_parameter" "aurora_conn_subnetid" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/aurora/subnetid"
}

data "aws_ssm_parameter" "aurora_conn_securitygroupid" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/aurora/securitygroupid"
}

#------------------------------------------------------------------------------
# Glue Aurora Connection Security Group
#------------------------------------------------------------------------------

module "conn_sg_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", "glueconnsgnaming"])
}

resource "aws_security_group" "conn_sg" {
  name = module.conn_sg_naming.name
  tags = module.conn_sg_naming.tags
}

#------------------------------------------------------------------------------
# Glue Aurora Connection
#------------------------------------------------------------------------------

module "aurora_connection" {
  source                 = "../../../modules/glue_connection"
  base_naming            = var.base_naming
  project_prefix         = var.project_prefix
  conn_name              = "auroraconn"
  password               = data.aws_ssm_parameter.aurora_conn_password.value
  username               = data.aws_ssm_parameter.aurora_conn_username.value
  jdbc_url               = data.aws_ssm_parameter.aurora_conn_jdbc_url.value
  subnet_id              = data.aws_ssm_parameter.aurora_conn_subnetid.value
  security_group_id_list = [data.aws_ssm_parameter.aurora_conn_securitygroupid.value]
}

#------------------------------------------------------------------------------
# Glue Ingest Job
#------------------------------------------------------------------------------

module "ingest_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=dev"
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
  }
}

#------------------------------------------------------------------------------
# Glue Cleaning Job
#------------------------------------------------------------------------------

data "aws_ssm_parameter" "ds_clean_library_version" {
  name = "/parameter/${var.site}/${var.environment}/codebuild/bright_clean_version"
}

data "aws_ssm_parameter" "bright_pypi_pipconf" {
  name = "/secure/${var.site}/${var.environment_devops}/codebuild/bright_pypi_pipconf"
}

module "cleaning_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=dev"
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
  glue_path           = "../src/mainprocess/glue/"
  job_name            = "cleaningjob"
  script_bucket       = var.project_objects.glue_bucket_id
  policy_variables    = var.project_objects

  job_arguments = {
    "--conf"                            = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"
    "--job-bookmark-option"             = "job-bookmark-disable"
    "--config_bucket"                   = var.project_objects.artifacts_bucket_id
    "--data_bucket"                     = var.project_objects.data_bucket_id
    "--agent_table_name"                = "bright_staging_agent_latest"
    "--office_table_name"               = "bright_staging_office_latest"
    "--team_table_name"                 = "bright_raw_team_latest"
    "--datalake-formats"                = "delta"
    "--glue_db"                         = aws_glue_catalog_database.dedup_process_glue_db.name
    "--model_version"                   = "1"
    "--additional-python-modules"       = "clean==${data.aws_ssm_parameter.ds_clean_library_version.value}"
    "--python-modules-installer-option" = "${data.aws_ssm_parameter.bright_pypi_pipconf.value}"
  }
}

#------------------------------------------------------------------------------
# Glue Splink Individuals Job
#------------------------------------------------------------------------------

locals {
  ind_dedup_job_workers = 20
}

module "ind_dedup_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=dev"
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
  glue_path           = "../src/mainprocess/glue/"
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
    "--office_table_name"         = "bright_staging_office_latest"
    "--ssm_params_base"           = "${var.site}/${var.environment}/${var.project_prefix}/aurora"
    "--county_info_s3_path"       = "s3://aue1d1z1s3boidhoidh-datastorage/raw_data/aue1d1z1glddatahubdatahub_utilities/counties_associate_with_bmls/RulesToDetermineNativeRecords.csv"
    "--max_records_per_file"      = 1000
    "--model_version"             = 1
    "--datalake-formats"          = "delta"
    "--glue_db"                   = aws_glue_catalog_database.dedup_process_glue_db.name
    "--additional-python-modules" = "splink==3.9.2"
    "--aurora_table"              = "public.individuals"
  }
}

#------------------------------------------------------------------------------
# Glue Splink Organizations Job
#------------------------------------------------------------------------------

locals {
  org_dedup_job_workers = 30
}

module "org_dedup_job" {
  source              = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//glue?ref=dev"
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
  glue_path           = "../src/mainprocess/glue/"
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
    "--ssm_params_base"           = "${var.site}/${var.environment}/${var.project_prefix}/aurora"
    "--county_info_s3_path"       = "s3://aue1d1z1s3boidhoidh-datastorage/raw_data/aue1d1z1glddatahubdatahub_utilities/counties_associate_with_bmls/RulesToDetermineNativeRecords.csv"
    "--max_records_per_file"      = 1000
    "--model_version"             = 1
    "--datalake-formats"          = "delta"
    "--glue_db"                   = aws_glue_catalog_database.dedup_process_glue_db.name
    "--additional-python-modules" = "splink==3.9.2"
    "--aurora_table"              = "public.organizations"
  }
}

# #------------------------------------------------------------------------------
# # Glue Crawler for Staging
# #------------------------------------------------------------------------------

module "staging_crawler_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
}
resource "aws_iam_role" "staging_crawler_role" {
  name = module.staging_crawler_role_naming.name
  tags = module.staging_crawler_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "GlueAssumeRole"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

module "staging_crawler_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "glr"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
}
resource "aws_glue_crawler" "staging_crawler" {
  database_name = aws_glue_catalog_database.dedup_process_glue_db.name
  name          = module.staging_crawler_naming.name
  tags          = module.staging_crawler_naming.tags
  role          = aws_iam_role.staging_crawler_role.arn

  delta_target {
    write_manifest            = false
    create_native_delta_table = true
    delta_tables = [
      "s3://${var.project_objects.data_bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.project_objects.lambda_ec_office_target_table_name}/",
      "s3://${var.project_objects.data_bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.project_objects.lambda_ec_agent_target_table_name}/"
    ]
  }
}

data "aws_iam_policy_document" "staging_glue_crawler_policy" {
  statement {
    sid    = "s3readandwrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [var.project_objects.data_bucket_arn,
    "${var.project_objects.data_bucket_arn}/*"]
  }
}

module "staging_glue_crawler_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawlerpolicy"])
}
resource "aws_iam_policy" "staging_glue_crawler_policy" {
  name        = module.staging_glue_crawler_policy_naming.name
  tags        = module.staging_glue_crawler_policy_naming.tags
  description = "IAM Policy for the Glue crawler that registers the staging tables"
  policy      = data.aws_iam_policy_document.staging_glue_crawler_policy.json
}

resource "aws_iam_role_policy_attachment" "staging_glue_crawler_policy_attachement" {
  role       = aws_iam_role.staging_crawler_role.name
  policy_arn = aws_iam_policy.staging_glue_crawler_policy.arn
}

resource "aws_iam_role_policy_attachment" "staging_glue_crawler_service_policy_attachement" {
  role       = aws_iam_role.staging_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
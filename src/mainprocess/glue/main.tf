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
# Glue Aurora Connection Security Group
#------------------------------------------------------------------------------

data "aws_subnet" "connection_subnet" {
  id = var.project_objects.aurora_subnetid
}

module "conn_sg_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", "glueconnsg"])
}

resource "aws_security_group" "conn_sg" {
  name   = module.conn_sg_naming.name
  tags   = module.conn_sg_naming.tags
  vpc_id = data.aws_subnet.connection_subnet.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "glue_sg_ingress" {
  security_group_id            = aws_security_group.conn_sg.id
  ip_protocol                  = -1
  referenced_security_group_id = aws_security_group.conn_sg.id
}

resource "aws_vpc_security_group_egress_rule" "glue_sg_egress" {
  security_group_id = aws_security_group.conn_sg.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
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
  jdbc_url               = var.project_objects.aurora_jdbc_url
  subnet_id              = var.project_objects.aurora_subnetid
  security_group_id_list = [aws_security_group.conn_sg.id]
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
    "--TempDir"             = "s3://${var.project_objects.glue_bucket_id}/tmp/"
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

locals {
  jfrog_url = "--${trimspace(replace(replace(data.aws_ssm_parameter.bright_pypi_pipconf.value, "[global]", ""), " ", ""))}"
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

locals {
  ind_dedup_job_workers = 20
  counties_path         = "s3://${var.project_objects.data_bucket_id}/raw_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/native_counties/RulesToDetermineNativeRecords.csv"
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

# #------------------------------------------------------------------------------
# # Glue Crawler for Staging
# #------------------------------------------------------------------------------

module "staging_crawler_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "stagingcrawler"])
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
  purpose     = join("", [var.project_prefix, "-", "stagingcrawler"])
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

  statement {
    sid    = "kmsread"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]
    resources = [var.project_objects.data_key_arn]
  }
}

module "staging_glue_crawler_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "stagingcrawlerpolicy"])
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
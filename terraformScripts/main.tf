provider "aws" {
  region = var.region[var.site]
  assume_role {
    role_arn     = var.role_arn
    session_name = "oidh"
  }
}

provider "archive" {}

data "aws_caller_identity" "current" {}

locals {
  lambda_runtime = "python3.10"
  lambda_handler = "lambda_function.lambda_handler"
}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

#------------------------------------------------------------------------------
# KMS Keys for the S3 Buckets and Glue
#------------------------------------------------------------------------------

# OIDH Dedup Process Encryption Key
module "data_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "datakey"])
}
module "data_key" {
  source             = "../modules/kms"
  key_name           = module.data_key_name.name
  key_tags           = module.data_key_name.tags
  key_description    = "KMS key used for data encryption of all the data in the datahub-dedup process"
  aws_account_number = data.aws_caller_identity.current.account_id
}

# Glue Data Encryption Key
module "glue_enc_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "glueenckey"])
}
module "glue_enc_key" {
  source             = "../modules/kms"
  key_name           = module.glue_enc_key_name.name
  key_tags           = module.glue_enc_key_name.tags
  key_description    = "KMS key used for data encryption of all the glue resources used in the datahub-dedup process"
  aws_account_number = data.aws_caller_identity.current.account_id
}

#------------------------------------------------------------------------------
# S3 Buckets
#------------------------------------------------------------------------------

# Data Bucket
module "s3b_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "datastorage"])
}

module "s3_data_bucket" {
  source                            = "../modules/s3"
  s3_bucket                         = module.s3b_data_naming.name
  s3_bucket_tags                    = module.s3b_data_naming.tags
  s3_bucket_key_id                  = module.data_key.key_id
  s3_bucket_key_arn                 = module.data_key.key_arn
  s3_bucket_tmp_expiration_days     = var.s3_bucket_tmp_expiration_days
  s3_bucket_objects_expiration_days = var.s3_bucket_objects_expiration_days
  s3_bucket_objects_transition_days = var.s3_bucket_objects_transition_days
}

# Artifacts Bucket
module "s3b_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "artifacts"])
}

module "s3_artifacts_bucket" {
  source                            = "../modules/s3"
  s3_bucket                         = module.s3b_artifacts_naming.name
  s3_bucket_tags                    = module.s3b_artifacts_naming.tags
  s3_bucket_key_id                  = module.data_key.key_id
  s3_bucket_key_arn                 = module.data_key.key_arn
  s3_bucket_tmp_expiration_days     = var.s3_bucket_tmp_expiration_days
  s3_bucket_objects_expiration_days = var.s3_bucket_objects_expiration_days
  s3_bucket_objects_transition_days = var.s3_bucket_objects_transition_days
}

# Glue Bucket
module "s3b_glue_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "glueartifacts"])
}

module "s3_glue_artifacts_bucket" {
  source                            = "../modules/s3"
  s3_bucket                         = module.s3b_glue_artifacts_naming.name
  s3_bucket_tags                    = module.s3b_glue_artifacts_naming.tags
  s3_bucket_key_id                  = module.glue_enc_key.key_id
  s3_bucket_key_arn                 = module.glue_enc_key.key_arn
  s3_bucket_tmp_expiration_days     = var.s3_bucket_tmp_expiration_days
  s3_bucket_objects_expiration_days = var.s3_bucket_objects_expiration_days
  s3_bucket_objects_transition_days = var.s3_bucket_objects_transition_days
}

#------------------------------------------------------------------------------
# S3 Data
#------------------------------------------------------------------------------

resource "aws_s3_object" "artifacts" {
  bucket                 = module.s3_artifacts_bucket.bucket_id
  for_each               = fileset("../src/artifacts/", "**")
  key                    = each.value
  source                 = "../src/artifacts/${each.value}"
  server_side_encryption = "AES256"
  etag                   = filemd5("../src/artifacts/${each.value}")
  #kms_key_id = module.data_key.key_arn
  bucket_key_enabled = true
}

resource "aws_s3_object" "glue_artifacts" {
  bucket                 = module.s3_glue_artifacts_bucket.bucket_id
  for_each               = fileset("../src/glue/", "**")
  key                    = each.value
  source                 = "../src/glue/${each.value}"
  server_side_encryption = "AES256"
  etag                   = filemd5("../src/glue/${each.value}")
  #kms_key_id = module.glue_enc_key.key_arn
  bucket_key_enabled = true
}

#------------------------------------------------------------------------------
# Glue DB
#------------------------------------------------------------------------------

module "glue_db_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "gluedb"])
}

resource "aws_glue_catalog_database" "dedup_process_glue_db" {
  name         = module.glue_db_naming.name
  location_uri = "s3://${module.s3_data_bucket.bucket_id}/"
  tags         = module.glue_db_naming.tags
}

#------------------------------------------------------------------------------
# Glue Security Configuration
#------------------------------------------------------------------------------

module "glue_secconfig_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "gls"
  purpose     = join("", [var.project_prefix, "-", "gluesecurityconfig"])
}

resource "aws_glue_security_configuration" "glue_security_config" {
  name = module.glue_secconfig_naming.name
  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = module.glue_enc_key.key_arn
    }
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = module.glue_enc_key.key_arn
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
# Glue Connection
#------------------------------------------------------------------------------

data "aws_subnet" "connection_subnet" {
  id = data.aws_ssm_parameter.redshift_conn_subnetid.value
}

module "glue_ingest_conn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glx"
  purpose     = join("", [var.project_prefix, "-", "ingestjobconnection"])
}

resource "aws_glue_connection" "redshift_connection" {
  connection_type = "JDBC"
  name            = module.glue_ingest_conn_naming.name
  tags            = module.glue_ingest_conn_naming.tags
  connection_properties = {
    JDBC_CONNECTION_URL = data.aws_ssm_parameter.redshift_conn_jdbc_url.value
    PASSWORD            = data.aws_ssm_parameter.redshift_conn_password.value
    USERNAME            = data.aws_ssm_parameter.redshift_conn_username.value
  }
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.connection_subnet.availability_zone
    subnet_id              = data.aws_subnet.connection_subnet.id
    security_group_id_list = [data.aws_ssm_parameter.redshift_conn_securitygroupid.value]
  }
}

#------------------------------------------------------------------------------
# Glue Ingest Job Role
#------------------------------------------------------------------------------
module "glue_ingest_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "ingestjobrole"])
}

resource "aws_iam_role" "ingest_glue_job_role" {
  name = module.glue_ingest_job_role_naming.name
  tags = module.glue_ingest_job_role_naming.tags
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

#------------------------------------------------------------------------------
# Glue Ingest Job
#------------------------------------------------------------------------------

module "glue_ingest_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "ingestjob"])
}

resource "aws_glue_job" "ingest_job" {
  name                   = module.glue_ingest_job_naming.name
  tags                   = module.glue_ingest_job_naming.tags
  role_arn               = aws_iam_role.ingest_glue_job_role.arn
  glue_version           = "4.0"
  worker_type            = var.glue_worker_type
  timeout                = var.glue_timeout
  security_configuration = aws_glue_security_configuration.glue_security_config.id
  number_of_workers      = var.glue_number_of_workers
  connections            = [aws_glue_connection.redshift_connection.name]
  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-job-insights"              = "true"
    "--enable-metrics"                   = "true"
    "--enable-auto-scaling"              = "true"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-glue-datacatalog"          = "true"
    "--conf"                             = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog",
    "--class"                            = "GlueApp"
    "--extra-jars" = join(",", ["s3://${module.s3_glue_artifacts_bucket.bucket_id}/${aws_s3_object.glue_artifacts["jars/delta-core_2.12-2.3.0.jar"].id}",
    "s3://${module.s3_glue_artifacts_bucket.bucket_id}/${aws_s3_object.glue_artifacts["jars/delta-storage-2.3.0.jar"].id}"])
    "--extra-py-files" = "s3://${module.s3_glue_artifacts_bucket.bucket_id}/${aws_s3_object.glue_artifacts["jars/delta-core_2.12-2.3.0.jar"].id}"
  }
  command {
    name            = "glueetl"
    script_location = "s3://${module.s3_glue_artifacts_bucket.bucket_id}/${aws_s3_object.glue_artifacts["scripts/ingest_job.py"].id}"
  }
  execution_property {
    max_concurrent_runs = var.glue_max_concurrent_runs
  }
}

#------------------------------------------------------------------------------
# Ingest job config loader
#------------------------------------------------------------------------------

module "lambda_config_loader_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "lambdaconfigloader"])
}
resource "aws_iam_role" "lambda_config_loader_role" {
  name = module.lambda_config_loader_role_naming.name
  tags = module.lambda_config_loader_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "LambdaAssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "archive_file" "lambda_config_loader_script" {
  type        = "zip"
  source_file = "../src/lambda/config-loader/lambda_function.py"
  output_path = "../src/lambda/config-loader/lambda_function.zip"
}

module "lambda_config_loader_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "lambdaconfigloader"])
}

resource "aws_lambda_function" "lambda_config_loader" {
  function_name                  = module.lambda_config_loader_naming.name
  tags                           = module.lambda_config_loader_naming.tags
  description                    = "Configuration loader for the OIDH dedup process"
  filename                       = data.archive_file.lambda_config_loader_script.output_path
  role                           = aws_iam_role.lambda_config_loader_role.arn
  handler                        = local.lambda_handler
  runtime                        = local.lambda_runtime
  source_code_hash               = data.archive_file.lambda_config_loader_script.output_base64sha256
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions

  environment {
    variables = {
      ARTIFACTS_BUCKET = module.s3_artifacts_bucket.bucket_id
      ETL_CONFIG_KEY   = "config/ingest_config.json"
    }
  }
}

#------------------------------------------------------------------------------
# Caar deltalake+geopy layer
#------------------------------------------------------------------------------

data "archive_file" "lambda_delta_geopy_layer" {
  type        = "zip"
  source_dir = "../src/lambda/layers/delta_geopy/"
  output_path = "../src/lambda/layers/delta_geopy.zip"
}

resource "aws_lambda_layer_version" "delta_geopy_layer" {
  filename   = data.archive_file.lambda_delta_geopy_layer.output_path
  layer_name = "delta_geopy"
  compatible_runtimes = ["python3.10"]
}

#------------------------------------------------------------------------------
# Caar Agent Staging job
#------------------------------------------------------------------------------

module "lambda_enrich_caar_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "lambdaenrichcaar"])
}
resource "aws_iam_role" "lambda_enrich_caar_role" {
  name = module.lambda_enrich_caar_role_naming.name
  tags = module.lambda_enrich_caar_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "LambdaAssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "archive_file" "lambda_caar_enrich_agent_script" {
  type        = "zip"
  source_file = "../src/lambda/caar-enrich-agent-data/lambda_function.py"
  output_path = "../src/lambda/caar-enrich-agent-data/lambda_function.zip"
}

module "lambda_caar_enrich_agent_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "lambdacaarenrichagent"])
}

resource "aws_lambda_function" "lambda_caar_enrich_agent" {
  function_name                  = module.lambda_caar_enrich_agent_naming.name
  tags                           = module.lambda_caar_enrich_agent_naming.tags
  description                    = "Lambda function that enriches agent data with the Organization Unique Id assigned by RESO"
  filename                       = data.archive_file.lambda_caar_enrich_agent_script.output_path
  role                           = aws_iam_role.lambda_enrich_caar_role.arn
  handler                        = local.lambda_handler
  runtime                        = local.lambda_runtime
  source_code_hash               = data.archive_file.lambda_caar_enrich_agent_script.output_base64sha256
  memory_size                    = var.lambda_ec_memory_size
  timeout                        = var.lambda_ec_timeout
  reserved_concurrent_executions = var.lambda_ec_reserved_concurrent_executions
  layers = [
    "arn:aws:lambda:${var.region[var.site]}:336392948345:layer:AWSSDKPandas-Python310:4",
    aws_lambda_layer_version.delta_geopy_layer.arn
    ]

  environment {
    variables = {
      S3_SOURCE_PATH = "s3://${module.s3_data_bucket.bucket_id}/raw_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_agent_table_name}/"
      S3_TARGET_PATH = "s3://${module.s3_data_bucket.bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_agent_table_name}/"
    }
  }
}

#------------------------------------------------------------------------------
# Caar Office Staging job
#------------------------------------------------------------------------------

data "archive_file" "lambda_caar_enrich_office_script" {
  type        = "zip"
  source_file = "../src/lambda/caar-enrich-office-data/lambda_function.py"
  output_path = "../src/lambda/caar-enrich-office-data/lambda_function.zip"
}

module "lambda_caar_enrich_office_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "lambdacaarenrichoffice"])
}

resource "aws_lambda_function" "lambda_caar_enrich_office" {
  function_name                  = module.lambda_caar_enrich_office_naming.name
  tags                           = module.lambda_caar_enrich_office_naming.tags
  description                    = "Lambda function that enriches office data with the Organization Unique Id assigned by RESO and county information"
  filename                       = data.archive_file.lambda_caar_enrich_office_script.output_path
  role                           = aws_iam_role.lambda_enrich_caar_role.arn
  handler                        = local.lambda_handler
  runtime                        = local.lambda_runtime
  source_code_hash               = data.archive_file.lambda_caar_enrich_office_script.output_base64sha256
  memory_size                    = var.lambda_ec_memory_size
  timeout                        = var.lambda_ec_timeout
  reserved_concurrent_executions = var.lambda_ec_reserved_concurrent_executions
  layers = [
    "arn:aws:lambda:${var.region[var.site]}:336392948345:layer:AWSSDKPandas-Python310:4",
    aws_lambda_layer_version.delta_geopy_layer.arn
    ]

  environment {
    variables = {
      S3_SOURCE_PATH = "s3://${module.s3_data_bucket.bucket_id}/raw_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_office_table_name}/"
      S3_TARGET_PATH = "s3://${module.s3_data_bucket.bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_office_table_name}/"
    }
  }
}

#------------------------------------------------------------------------------
# Glue Crawler for Staging
#------------------------------------------------------------------------------

module "staging_crawler_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
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
  base_object = module.base_naming
  type        = "glr"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
}
resource "aws_glue_crawler" "stagin_crawler" {
  database_name = aws_glue_catalog_database.dedup_process_glue_db.name
  name          = module.staging_crawler_naming.name
  tags          = module.staging_crawler_naming.tags
  role          = aws_iam_role.staging_crawler_role.arn

  delta_target {
    write_manifest = false
    create_native_delta_table = true
    delta_tables = [
    "s3://${module.s3_data_bucket.bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_office_table_name}/",
    "s3://${module.s3_data_bucket.bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_office_table_name}/"
    ]
  }
}

#------------------------------------------------------------------------------
# Step function definition
#------------------------------------------------------------------------------

module "sfn_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "etlsfn"])
}
resource "aws_iam_role" "sfn_role" {
  name = module.sfn_role_naming.name
  tags = module.sfn_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "SfnAssumeRole"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

module "etl_sfn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "stm"
  purpose     = join("", [var.project_prefix, "-", "etlsfn"])
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = module.etl_sfn_naming.name
  tags     = module.etl_sfn_naming.tags
  role_arn = aws_iam_role.sfn_role.arn
  type     = "STANDARD"

  definition = <<EOF
{
  "StartAt": "load-ingest-conf",
  "States": {
    "load-ingest-conf": {
      "Next": "ingest-job-mapping",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ClientExecutionTimeoutException",
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": ${var.lambda_retry_interval},
          "MaxAttempts": ${var.lambda_retry_max_attempts},
          "BackoffRate": ${var.lambda_retry_backoff_rate}
        }
      ],
      "Type": "Task",
      "OutputPath": "$.Payload",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lambda_config_loader.arn}",
        "Payload.$": "$"
      }
    },
    "ingest-job-mapping": {
      "Type": "Map",
      "Next": "enrich-caar-data",
      "ResultPath": null,
      "Iterator": {
        "StartAt": "ingest-job",
        "States": {
          "ingest-job": {
            "End": true,
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "IntervalSeconds": ${var.glue_retry_interval},
                "MaxAttempts": ${var.glue_retry_max_attempts},
                "BackoffRate": ${var.glue_retry_backoff_rate}
              }
            ],
            "Type": "Task",
            "Resource": "arn:aws:states:::glue:startJobRun.sync",
            "Parameters": {
              "JobName": "${aws_glue_job.ingest_job.id}",
              "Arguments": {
                "--target.$": "$.target",
                "--target_prefixes.$": "$.target_prefixes",
                "--catalog_table.$": "$.catalog_table",
                "--catalog_database.$": "$.catalog_database",
                "--connection_type.$": "$.connection_type",
                "--options.$": "$.options"
              },
              "Timeout": ${var.glue_timeout},
              "NotificationProperty": {
                "NotifyDelayAfter": 5
              }
            }
          }
        }
      },
      "ItemsPath": "$.tables",
      "MaxConcurrency": ${var.glue_max_concurrent_runs}
    },
    "enrich-caar-data": {
      "Type": "Parallel",
      "End": true,
      "Branches": [
        {
         "StartAt": "enrich-agent",
         "States": {
           "enrich-agent": {
            "End": true,
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ClientExecutionTimeoutException",
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException"
                ],
                "IntervalSeconds": ${var.lambda_ec_retry_interval},
                "MaxAttempts": ${var.lambda_ec_retry_max_attempts},
                "BackoffRate": ${var.lambda_ec_retry_backoff_rate}
              }
              ],
              "Type": "Task",
              "OutputPath": "$.Payload",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
              "FunctionName": "${aws_lambda_function.lambda_caar_enrich_agent.arn}",
              "Payload.$": "$"
            }
          }
        }
      },
        {
         "StartAt": "enrich-office",
         "States": {
           "enrich-office": {
            "End": true,
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ClientExecutionTimeoutException",
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException"
                ],
                "IntervalSeconds": ${var.lambda_ec_retry_interval},
                "MaxAttempts": ${var.lambda_ec_retry_max_attempts},
                "BackoffRate": ${var.lambda_ec_retry_backoff_rate}
              }
              ],
              "Type": "Task",
              "OutputPath": "$.Payload",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
              "FunctionName": "${aws_lambda_function.lambda_caar_enrich_office.arn}",
              "Payload.$": "$"
            }
          }
        }
      }
      ]
    }
  }
}
EOF
}

#------------------------------------------------------------------------------
# ETL cron trigger
#------------------------------------------------------------------------------

# Cron trigger execution role
module "trigger_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "crontrigger"])
}
resource "aws_iam_role" "crontrigger_role" {
  name = module.trigger_role_naming.name
  tags = module.trigger_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "CronTriggerAssumeRole"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

# Cron trigger
module "cron_trigger_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwr"
  purpose     = join("", [var.project_prefix, "-", "crontrigger"])
}

resource "aws_cloudwatch_event_rule" "cron_trigger" {
  name                = module.cron_trigger_naming.name
  tags                = module.cron_trigger_naming.tags
  is_enabled          = true
  schedule_expression = var.cron_schedule
}

resource "aws_cloudwatch_event_target" "etl_sfn" {
  rule      = aws_cloudwatch_event_rule.cron_trigger.name
  target_id = "StartStateMachine"
  arn       = aws_sfn_state_machine.sfn_state_machine.arn
  role_arn  = aws_iam_role.crontrigger_role.arn
}

#------------------------------------------------------------------------------
# Permissions
#------------------------------------------------------------------------------

#### Glue job policies ####
data "aws_iam_policy_document" "glue_ingest_job_policy" {

  statement {
    sid    = "s3readandwrite"
    effect = "Allow"
    actions = [
      "s3:Abort*",
      "s3:DeleteObject*",
      "s3:GetBucket*",
      "s3:GetObject*",
      "s3:List*",
      "s3:PutObject",
      "s3:PutObjectLegalHold",
      "s3:PutObjectRetention",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [module.s3_data_bucket.bucket_arn,
      "${module.s3_data_bucket.bucket_arn}/*",
      module.s3_glue_artifacts_bucket.bucket_arn,
    "${module.s3_glue_artifacts_bucket.bucket_arn}/*"]
  }

  statement {
    sid       = "loggroupmanagement"
    effect    = "Allow"
    actions   = ["logs:AssociateKmsKey"]
    resources = ["arn:aws:logs:${var.region[var.site]}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/*"]
  }
}

module "glue_ingest_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "glueingestpolicy"])
}
resource "aws_iam_policy" "glue_ingest_policy" {
  name        = module.glue_ingest_policy_naming.name
  tags        = module.glue_ingest_policy_naming.tags
  description = "IAM Policy for the Glue ingest job"
  policy      = data.aws_iam_policy_document.glue_ingest_job_policy.json
}

resource "aws_iam_role_policy_attachment" "glue_policy_attachement" {
  role       = aws_iam_role.ingest_glue_job_role.name
  policy_arn = aws_iam_policy.glue_ingest_policy.arn
}

resource "aws_iam_role_policy_attachment" "glue_service_policy_attachement" {
  role       = aws_iam_role.ingest_glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Read and write access for the data kms key
resource "aws_kms_grant" "grant_read_data" {
  key_id            = module.data_key.key_id
  grantee_principal = aws_iam_role.ingest_glue_job_role.arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

resource "aws_kms_grant" "grant_read_glue_artifacts" {
  key_id            = module.glue_enc_key.key_id
  grantee_principal = aws_iam_role.ingest_glue_job_role.arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

#### Lambda config loader policies ####
data "aws_iam_policy_document" "lambda_config_loader_policy" {
  statement {
    sid    = "s3read"
    effect = "Allow"
    actions = [
      "s3:GetBucket*",
      "s3:GetObject*",
      "s3:List*"
    ]
    resources = [module.s3_artifacts_bucket.bucket_arn,
    "${module.s3_artifacts_bucket.bucket_arn}/*"]
  }
}

module "lambda_config_loader_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "lambdaconfigloaderpolicy"])
}
resource "aws_iam_policy" "lambda_config_loader_policy" {
  name        = module.lambda_config_loader_policy_naming.name
  tags        = module.lambda_config_loader_policy_naming.tags
  description = "IAM Policy for the Lambda configuration loader function"
  policy      = data.aws_iam_policy_document.lambda_config_loader_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_config_loader_policy_attachement" {
  role       = aws_iam_role.lambda_config_loader_role.name
  policy_arn = aws_iam_policy.lambda_config_loader_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec_policy_attachement" {
  role       = aws_iam_role.lambda_config_loader_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read and write access for the data kms key
resource "aws_kms_grant" "grant_read_data_ingest" {
  key_id            = module.data_key.key_id
  grantee_principal = aws_iam_role.lambda_config_loader_role.arn
  operations        = ["Decrypt"]
}

#### Lambda enrich caar data policies ####
data "aws_iam_policy_document" "lambda_enrich_caar_policy" {
  statement {
    sid    = "s3readandwrite"
    effect = "Allow"
    actions = [
      "s3:Abort*",
      "s3:DeleteObject*",
      "s3:GetBucket*",
      "s3:GetObject*",
      "s3:List*",
      "s3:PutObject",
      "s3:PutObjectLegalHold",
      "s3:PutObjectRetention",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [module.s3_data_bucket.bucket_arn,
    "${module.s3_data_bucket.bucket_arn}/*"]
  }
}

module "lambda_enrich_caar_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "lambdaenrichcaarpolicy"])
}
resource "aws_iam_policy" "lambda_enrich_caar_policy" {
  name        = module.lambda_enrich_caar_policy_naming.name
  tags        = module.lambda_enrich_caar_policy_naming.tags
  description = "IAM Policy for the Lambda Enrich Caar data functions"
  policy      = data.aws_iam_policy_document.lambda_enrich_caar_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_enrich_data_policy_attachement" {
  role       = aws_iam_role.lambda_enrich_caar_role.name
  policy_arn = aws_iam_policy.lambda_enrich_caar_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec_policy_attachement_caar" {
  role       = aws_iam_role.lambda_enrich_caar_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read and write access for the data kms key
resource "aws_kms_grant" "grant_read_write_data_enrich_caar" {
  key_id            = module.data_key.key_id
  grantee_principal = aws_iam_role.lambda_enrich_caar_role.arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

#### Staging Glue crawler policies ####
data "aws_iam_policy_document" "staging_glue_crawler_policy" {
  statement {
    sid    = "s3readandwrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [module.s3_data_bucket.bucket_arn,
    "${module.s3_data_bucket.bucket_arn}/*"]
  }
}

module "staging_glue_crawler_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
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

# Read and write access for the data kms key
resource "aws_kms_grant" "grant_read_write_data_staging_crawler" {
  key_id            = module.data_key.key_id
  grantee_principal = aws_iam_role.staging_crawler_role.arn
  operations        = ["Decrypt", "GenerateDataKey"]
}

#### Step function policies ####

data "aws_iam_policy_document" "etl_sfn_policy" {
  statement {
    sid     = "lambdaexec"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.lambda_config_loader.arn,
      "${aws_lambda_function.lambda_config_loader.arn}:*",
      aws_lambda_function.lambda_caar_enrich_office.arn,
      "${aws_lambda_function.lambda_caar_enrich_office.arn}:*",
      aws_lambda_function.lambda_caar_enrich_agent.arn,
    "${aws_lambda_function.lambda_caar_enrich_agent.arn}:*"
    ]
  }

  statement {
    sid    = "glueexec"
    effect = "Allow"
    actions = [
      "glue:BatchStopJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:StartJobRun"
    ]
    resources = [aws_glue_job.ingest_job.arn]
  }
}

module "elt_sfn_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "etlsfnpolicy"])
}
resource "aws_iam_policy" "etl_sfn_policy" {
  name        = module.elt_sfn_policy_naming.name
  tags        = module.elt_sfn_policy_naming.tags
  description = "IAM Policy for the orchestration Step Function"
  policy      = data.aws_iam_policy_document.etl_sfn_policy.json
}

resource "aws_iam_role_policy_attachment" "etl_sfn_policy_attachement" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.etl_sfn_policy.arn
}

# Cron trigger policies

data "aws_iam_policy_document" "cron_trigger_policy" {
  statement {
    sid       = "stfexecaccess"
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.sfn_state_machine.arn]
  }
}

module "cron_trigger_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "crontriggerpolicy"])
}
resource "aws_iam_policy" "cron_trigger_policy" {
  name        = module.cron_trigger_policy_naming.name
  tags        = module.cron_trigger_policy_naming.tags
  description = "IAM Policy for the EventBridge cron trigger of the dedupe process etl"
  policy      = data.aws_iam_policy_document.cron_trigger_policy.json
}

resource "aws_iam_role_policy_attachment" "cron_trigger_policy_attachement" {
  role       = aws_iam_role.crontrigger_role.name
  policy_arn = aws_iam_policy.cron_trigger_policy.arn
}

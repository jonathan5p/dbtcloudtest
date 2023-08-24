provider "aws" {
  region = var.region[var.site]
  assume_role {
    role_arn     = var.role_arn
    session_name = "oidh"
  }
}

data "aws_caller_identity" "current" {}

locals {
  lambda_runtime = "python3.10"
  lambda_handler = "lambda_function.lambda_handler"
}

data "aws_region" "current" {}

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
  server_side_encryption = "aws:kms"
  kms_key_id = module.data_key.key_arn
  bucket_key_enabled     = true
}

resource "aws_s3_object" "glue_artifacts" {
  bucket                 = module.s3_glue_artifacts_bucket.bucket_id
  for_each               = fileset("../src/glue/", "**")
  key                    = each.value
  source                 = "../src/glue/${each.value}"
  server_side_encryption = "aws:kms"
  kms_key_id = module.glue_enc_key.key_arn
  bucket_key_enabled     = true
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

data "aws_ssm_parameters_by_path" "redshift_credentials"{
  path = "/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift"
}

#------------------------------------------------------------------------------
# Glue Connection
#------------------------------------------------------------------------------

data "aws_subnet" "connection_subnet" {
  id = var.glue_redshift_conn_subnet_id
}

module "glue_connection_sg_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", "ingestjobconnectionsg"])
}

resource "aws_security_group" "glue_connection_sg" {
  name        = module.glue_connection_sg_naming.name
  tags        = module.glue_connection_sg_naming.tags
  vpc_id      = data.aws_subnet.connection_subnet.vpc_id
  description = "Security group used by the OIDH dedup process glue connection"
  ingress {
    description = "Self-referencing all tcp"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
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
    JDBC_CONNECTION_URL = data.aws_ssm_parameters_by_path.redshift_credentials.values[0]
    PASSWORD = data.aws_ssm_parameters_by_path.redshift_credentials.values[1]
    USERNAME = data.aws_ssm_parameters_by_path.redshift_credentials.values[2]
  }
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.connection_subnet.availability_zone
    subnet_id              = data.aws_subnet.connection_subnet.id
    security_group_id_list = [aws_security_group.glue_connection_sg.id]
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
      "ResultPath": null,
      "End": true,
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
    }
  }
}
EOF
}
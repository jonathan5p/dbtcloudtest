provider "aws" {
  region  = var.region[var.site]
  profile = "bright_datascience_queryadmin"
  #assume_role {
  #  role_arn     = var.role_arn
  #  session_name = "oidh"
  #}
}

provider "archive" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

#------------------------------------------------------------------------------
# Glue
#------------------------------------------------------------------------------

module "gluetest" {
  source = "../src/mainprocess/glue"

  base_naming       = module.base_naming
  environment       = var.environment
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  project_objects = {
    "glue_bucket" : module.s3_glue_artifacts_bucket
    "data_bucket" : module.s3_data_bucket
    "glue_enc_key" : module.glue_enc_key
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
resource "aws_glue_crawler" "staging_crawler" {
  database_name = module.gluetest.functions_mapping.gluedb_name
  name          = module.staging_crawler_naming.name
  tags          = module.staging_crawler_naming.tags
  role          = aws_iam_role.staging_crawler_role.arn

  delta_target {
    write_manifest            = false
    create_native_delta_table = true
    delta_tables = [
      "s3://${module.s3_data_bucket.bucket_id}/staging_data/${module.gluetest.functions_mapping.gluedb_name}/${var.lambda_ec_office_target_table_name}/",
      "s3://${module.s3_data_bucket.bucket_id}/staging_data/${module.gluetest.functions_mapping.gluedb_name}/${var.lambda_ec_agent_target_table_name}/"
    ]
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
  source_file = "../src/lambda/config_loader/lambda_function.py"
  output_path = "../src/lambda/config_loader/lambda_function.zip"
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

resource "aws_lambda_layer_version" "delta_geopy_layer" {
  filename            = "../src/lambda/layers/delta_geopy.zip"
  layer_name          = "delta_geopy"
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
  source_file = "../src/lambda/caar_enrich_agent_data/lambda_function.py"
  output_path = "../src/lambda/caar_enrich_agent_data/lambda_function.zip"
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
      S3_SOURCE_PATH = "s3://${module.s3_data_bucket.bucket_id}/raw_data/${module.gluetest.functions_mapping.gluedb_name}/${var.lambda_ec_agent_source_table_name}/"
      S3_TARGET_PATH = "s3://${module.s3_data_bucket.bucket_id}/staging_data/${module.gluetest.functions_mapping.gluedb_name}/${var.lambda_ec_agent_target_table_name}/"
    }
  }
}

#------------------------------------------------------------------------------
# Caar Office Staging job
#------------------------------------------------------------------------------

data "archive_file" "lambda_caar_enrich_office_script" {
  type        = "zip"
  source_file = "../src/lambda/caar_enrich_office_data/lambda_function.py"
  output_path = "../src/lambda/caar_enrich_office_data/lambda_function.zip"
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
      S3_SOURCE_PATH = "s3://${module.s3_data_bucket.bucket_id}/raw_data/${module.gluetest.functions_mapping.gluedb_name}/${var.lambda_ec_office_source_table_name}/"
      S3_TARGET_PATH = "s3://${module.s3_data_bucket.bucket_id}/staging_data/${module.gluetest.functions_mapping.gluedb_name}/${var.lambda_ec_office_target_table_name}/"
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
  name       = module.etl_sfn_naming.name
  tags       = module.etl_sfn_naming.tags
  role_arn   = aws_iam_role.sfn_role.arn
  type       = "STANDARD"
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
                              "JobName": "${module.gluetest.functions_mapping.ingestjob.job_id}",
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
              "Next": "start-glue-staging-crawler",
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
          },
          "start-glue-staging-crawler": {
              "End": true,
              "Retry": [
                  {
                      "ErrorEquals": [
                          "States.ALL"
                      ],
                      "IntervalSeconds": 1,
                      "MaxAttempts": 3,
                      "BackoffRate": 2
                  }
              ],
              "Type": "Task",
              "Resource": "arn:aws:states:::aws-sdk:glue:startCrawler",
              "Parameters": {
                  "Name":"${module.staging_crawler_naming.name}"
              }
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
  is_enabled          = var.cron_trigger_enabled
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
# data "aws_iam_policy_document" "glue_ingest_job_policy" {

#   statement {
#     sid    = "s3readandwrite"
#     effect = "Allow"
#     actions = [
#       "s3:Abort*",
#       "s3:DeleteObject*",
#       "s3:GetBucket*",
#       "s3:GetObject*",
#       "s3:List*",
#       "s3:PutObject",
#       "s3:PutObjectLegalHold",
#       "s3:PutObjectRetention",
#       "s3:PutObjectTagging",
#       "s3:PutObjectVersionTagging"
#     ]
#     resources = [module.s3_data_bucket.bucket_arn,
#       "${module.s3_data_bucket.bucket_arn}/*",
#       module.s3_glue_artifacts_bucket.bucket_arn,
#     "${module.s3_glue_artifacts_bucket.bucket_arn}/*"]
#   }

#   statement {
#     sid       = "loggroupmanagement"
#     effect    = "Allow"
#     actions   = ["logs:AssociateKmsKey"]
#     resources = ["arn:aws:logs:${var.region[var.site]}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/*"]
#   }
# }

# module "glue_ingest_policy_naming" {
#   source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
#   base_object = module.base_naming
#   type        = "ipl"
#   purpose     = join("", [var.project_prefix, "-", "glueingestpolicy"])
# }
# resource "aws_iam_policy" "glue_ingest_policy" {
#   name        = module.glue_ingest_policy_naming.name
#   tags        = module.glue_ingest_policy_naming.tags
#   description = "IAM Policy for the Glue ingest job"
#   policy      = data.aws_iam_policy_document.glue_ingest_job_policy.json
# }

# resource "aws_iam_role_policy_attachment" "glue_policy_attachement" {
#   role       = module.ingest_job.role_name
#   policy_arn = aws_iam_policy.glue_ingest_policy.arn
# }

# resource "aws_iam_role_policy_attachment" "glue_service_policy_attachement" {
#   role       = module.ingest_job.role_name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
# }

# Read and write access for the data kms key
resource "aws_kms_grant" "grant_read_data" {
  key_id            = module.data_key.key_id
  grantee_principal = module.gluetest.functions_mapping.ingestjob.role_arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

resource "aws_kms_grant" "grant_read_glue_artifacts" {
  key_id            = module.glue_enc_key.key_id
  grantee_principal = module.gluetest.functions_mapping.ingestjob.role_arn
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
      "glue:StartJobRun",
      "glue:StartCrawler"
    ]
    resources = [module.gluetest.functions_mapping.ingestjob.job_arn, aws_glue_crawler.staging_crawler.arn]
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

#------------------------------------------------------------------------------
# ECS Configuration
#------------------------------------------------------------------------------

module "ecr_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ecr"
  purpose     = join("", [var.project_prefix, "-alayapush"])
}

resource "aws_ecr_repository" "app_sync" {
  name                 = module.ecr_naming.name
  image_tag_mutability = "MUTABLE"
  tags                 = module.ecr_naming.tags
}

resource "aws_ssm_parameter" "repository_url" {
  name  = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/ecs_task_push_repository_url"
  type  = "String"
  value = aws_ecr_repository.app_sync.repository_url
}

module "ecs_task_cloudwatch_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwg"
  purpose     = join("", [var.project_prefix, "-", "alayapush"])
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = module.ecs_task_cloudwatch_naming.name
  retention_in_days = var.retention_days_ecs_alaya_logs
  tags              = module.ecs_task_cloudwatch_naming.tags
}

module "ipl_ecs_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "taskpolicy"])
}

resource "aws_iam_policy" "policy_ecs" {
  name   = module.ipl_ecs_task_naming.name
  policy = data.aws_iam_policy_document.policy_ecs.json
}

data "aws_iam_policy_document" "policy_ecs" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetBucketAcl",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${module.s3_data_bucket.bucket_id}/*",
      "arn:aws:s3:::${module.s3_data_bucket.bucket_id}/"
    ]
  }

  statement {
    actions = [
      "glue:GetTable",
      "glue:BatchCreatePartition",
      "glue:UpdateTable",
      "glue:CreateTable"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
    ]
  }

  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*"
    ]
  }
}

data "aws_iam_policy_document" "assume_ecs_task" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  }
}

module "iro_ecs_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "taskrole"])
}

resource "aws_iam_role" "ecs_task" {
  name               = module.iro_ecs_task_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task.json
  tags               = module.iro_ecs_task_naming.tags
}

resource "aws_iam_role_policy_attachment" "dev_deployment" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.policy_ecs.arn
}


module "ect_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ect"
  purpose     = join("", [var.project_prefix, "-", "alayapush"])
}


resource "aws_ecs_task_definition" "task_ecs" {
  family = module.ect_task_naming.name
  container_definitions = jsonencode([
    {
      name      = "oidh-push"
      image     = "${aws_ecr_repository.app_sync.repository_url}:latest"
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = data.aws_region.current.name
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-stream-prefix = "ecs"
        }
      }
  }])

  cpu                      = var.ecs_task_alaya_cpu
  memory                   = var.ecs_task_alaya_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.ecs_task.arn
  requires_compatibilities = ["FARGATE"]

  runtime_platform {
    operating_system_family = "LINUX"
  }
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

module "iro_ecs_task_execution_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayapushexecution"])
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name                = module.iro_ecs_task_execution_naming.name
  assume_role_policy  = data.aws_iam_policy_document.ecs_task_execution_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  tags                = module.iro_ecs_task_execution_naming.tags
}

module "alayasync" {
  source = "../src/alayasync"

  environment       = var.environment
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  project_objects = {
    "bucket_id" : module.s3_data_bucket.bucket_id
    "bucket_arn" : module.s3_data_bucket.bucket_arn
    "data_key_id" : module.data_key.key_id
    "data_key_arn" : module.data_key.key_arn
  }
}

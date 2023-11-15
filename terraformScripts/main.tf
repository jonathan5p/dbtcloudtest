provider "aws" {
  region = var.region[var.site]
  assume_role {
    role_arn     = var.role_arn
    session_name = "oidh"
  }
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
  source             = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//kms?ref=develop"
  key_name           = module.data_key_name.name
  key_tags           = module.data_key_name.tags
  key_admins         = var.kms_data_admins
  key_users          = var.kms_data_users
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
  source             = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//kms?ref=develop"
  key_name           = module.glue_enc_key_name.name
  key_tags           = module.glue_enc_key_name.tags
  key_admins         = var.kms_glue_admins
  key_users          = var.kms_glue_users
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
  bucket_key_enabled     = true
}

#------------------------------------------------------------------------------
# Glue max records per file parameter
#------------------------------------------------------------------------------

# resource "aws_ssm_parameter" "max_records_param" {
#   name  = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/alayasync/max_records"
#   type  = "String"
#   value = var.glue_max_records_per_file
# }

#------------------------------------------------------------------------------
# Main process
#------------------------------------------------------------------------------

# data "aws_ssm_parameter" "lambda_chatbot_arn" {
#   name = "/parameter/${var.site}/${var.environment}/data/lambda_chatbot_function_arn"
# }

# module "mainprocess" {
#   source = "../src/mainprocess"

#   base_naming        = module.base_naming
#   environment        = var.environment
#   environment_devops = var.environment_devops
#   project_app_group  = var.project_app_group
#   project_ledger     = var.project_ledger
#   project_prefix     = var.project_prefix
#   site               = var.site
#   tier               = var.tier
#   zone               = var.zone

#   project_objects = {
#     "glue_bucket_id"                     = module.s3_glue_artifacts_bucket.bucket_id
#     "data_bucket_id"                     = module.s3_data_bucket.bucket_id
#     "artifacts_bucket_id"                = module.s3_artifacts_bucket.bucket_id
#     "glue_bucket_arn"                    = module.s3_glue_artifacts_bucket.bucket_arn
#     "data_bucket_arn"                    = module.s3_data_bucket.bucket_arn
#     "artifacts_bucket_arn"               = module.s3_artifacts_bucket.bucket_arn
#     "glue_enc_key"                       = module.glue_enc_key.key_arn
#     "data_key_arn"                       = module.data_key.key_arn
#     "cron_schedule"                      = var.cron_schedule
#     "cron_trigger_enabled"               = var.cron_trigger_enabled
#     "lambda_ec_agent_target_table_name"  = var.lambda_ec_agent_target_table_name
#     "lambda_ec_office_target_table_name" = var.lambda_ec_office_target_table_name
#     "lambda_ec_agent_source_table_name"  = var.lambda_ec_agent_source_table_name
#     "lambda_ec_office_source_table_name" = var.lambda_ec_office_source_table_name
#     "aurora_backup_retention_period"     = var.aurora_backup_retention_period
#     "aurora_preferred_backup_window"     = var.aurora_preferred_backup_window
#     "aurora_max_capacity"                = var.aurora_max_capacity
#     "aurora_min_capacity"                = var.aurora_min_capacity
#     "max_records_per_file"               = var.glue_max_records_per_file
#     "alaya_trigger_key"                  = var.alaya_trigger_key
#     "glue_geosvc_subnetid"               = var.glue_geosvc_subnetid
#     "lambda_chatbot_arn"                 = data.aws_ssm_parameter.lambda_chatbot_arn.value
#   }
# }

#------------------------------------------------------------------------------
# Alaya Sync Process
#------------------------------------------------------------------------------

#data "aws_ssm_parameter" "ecs_cluster_name" {
#  name = "/parameter/${var.site}/${var.environment}/data/ecs_cluster"
#}

#data "aws_ssm_parameter" "dynamo_async_name" {
#  name = "/parameter/${var.site}/${var.environment}/data/dynamo_async"
#}

#module "alayasync" {
#  source = "../src/alayasync"

#  environment       = var.environment
#  project_app_group = var.project_app_group
#  project_ledger    = var.project_ledger
#  project_prefix    = var.project_prefix
#  site              = var.site
#  tier              = var.tier
#  zone              = var.zone

#  project_objects = {
#    "alayasyncdb"           = module.mainprocess.alayasync_db
#    "alayasyncdb_path"      = module.mainprocess.alayasyncdb_path
#    "alayatrigger_key"      = var.alaya_trigger_key
#    "async_lambda_timeout"  = "890"
#    "athena_bucket_id"      = module.athena.bucket_id
#    "bucket_id"             = module.s3_data_bucket.bucket_id
#    "bucket_arn"            = module.s3_data_bucket.bucket_arn
#    "concurrent_tasks"      = var.concurrent_tasks
#    "data_key_id"           = module.data_key.key_id
#    "data_key_arn"          = module.data_key.key_arn
#    "dynamo_table_async"    = data.aws_ssm_parameter.dynamo_async_name.value
#    "ecs_cluster"           = data.aws_ssm_parameter.ecs_cluster_name.value
#    "ecs_subnets"           = var.ecs_subnets
#    "ecs_task_alaya_cpu"    = var.ecs_task_alaya_cpu
#    "ecs_task_alaya_memory" = var.ecs_task_alaya_memory
#    "lambda_chatbot_arn"    = data.aws_ssm_parameter.lambda_chatbot_arn.value
#    "ttl_days_async"        = var.ttl_days_async
#  }
#}

#------------------------------------------------------------------------------
# Athena
#------------------------------------------------------------------------------

#module "athena" {
#  source = "../src/athena"

#  environment       = var.environment
#  project_app_group = var.project_app_group
#  project_ledger    = var.project_ledger
#  project_prefix    = var.project_prefix
#  site              = var.site
#  tier              = var.tier
#  zone              = var.zone

#}

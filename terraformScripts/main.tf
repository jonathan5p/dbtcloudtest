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

resource "aws_ssm_parameter" "max_records_param" {
  name  = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/alayasync/max_records"
  type  = "String"
  value = var.glue_max_records_per_file
}

#------------------------------------------------------------------------------
# Main process
#------------------------------------------------------------------------------

module "mainprocess" {
  source = "../src/mainprocess"

  base_naming        = module.base_naming
  environment        = var.environment
  environment_devops = var.environment_devops
  project_app_group  = var.project_app_group
  project_ledger     = var.project_ledger
  project_prefix     = var.project_prefix
  site               = var.site
  tier               = var.tier
  zone               = var.zone

  project_objects = {
    "glue_bucket_id"                     = module.s3_glue_artifacts_bucket.bucket_id
    "data_bucket_id"                     = module.s3_data_bucket.bucket_id
    "artifacts_bucket_id"                = module.s3_artifacts_bucket.bucket_id
    "glue_bucket_arn"                    = module.s3_glue_artifacts_bucket.bucket_arn
    "data_bucket_arn"                    = module.s3_data_bucket.bucket_arn
    "artifacts_bucket_arn"               = module.s3_artifacts_bucket.bucket_arn
    "glue_enc_key"                       = module.glue_enc_key.key_arn
    "data_key_arn"                       = module.data_key.key_arn
    "cron_schedule"                      = var.cron_schedule
    "cron_trigger_enabled"               = var.cron_trigger_enabled
    "lambda_ec_agent_target_table_name"  = var.lambda_ec_agent_target_table_name
    "lambda_ec_office_target_table_name" = var.lambda_ec_office_target_table_name
    "lambda_ec_agent_source_table_name"  = var.lambda_ec_agent_source_table_name
    "lambda_ec_office_source_table_name" = var.lambda_ec_office_source_table_name
    "aurora_backup_retention_period"     = var.aurora_backup_retention_period
    "aurora_preferred_backup_window"     = var.aurora_preferred_backup_window
    "aurora_max_capacity"                = var.aurora_max_capacity
    "aurora_min_capacity"                = var.aurora_min_capacity
    "max_records_per_file"               = var.glue_max_records_per_file
    "alaya_trigger_key"                  = var.alaya_trigger_key
  }
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
      "arn:aws:s3:::${module.s3_data_bucket.bucket_id}",
      "arn:aws:s3:::${module.athena.bucket_id}/*",
      "arn:aws:s3:::${module.athena.bucket_id}"
    ]
  }

  statement {
    actions = [
      "s3:GetBucketLocation"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::*"
    ]
  }

  statement {
    actions = [
      "glue:GetTable",
      "glue:BatchCreatePartition",
      "glue:UpdateTable",
      "glue:CreateTable",
      "glue:GetPartitions",
      "glue:GetPartition"
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
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:GetRecords",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table",
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*"
    ]
  }

  statement {
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetQueryResultsStream"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:athena:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workgroup/*"
    ]
  }

  statement {
      effect = "Allow"
      actions =  [
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant"
      ]
      resources = [
        "${module.data_key.key_arn}"
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
      environment = [{
        "name" : "athena_bucket",
        "value" : "${module.athena.bucket_id}"
      }]
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

data "aws_ssm_parameter" "ecs_cluster_name" {
  name = "/parameter/${var.site}/${var.environment}/data/ecs_cluster"
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
    "ecs_cluster" : data.aws_ssm_parameter.ecs_cluster_name.value
    "task_definition" : module.ect_task_naming.name
    "ecs_subnets" : var.ecs_subnets
    "alayasyncdb" : module.mainprocess.alayasync_db
    "alayasyncdb_path" : module.mainprocess.alayasyncdb_path
    "concurrent_tasks" : var.concurrent_tasks
    "alaya_trigger_key": var.alaya_trigger_key
  }
}

module "athena" {
  source = "../src/athena"

  environment       = var.environment
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

}

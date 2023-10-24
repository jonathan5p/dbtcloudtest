terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  athena_workgroup = "${var.site}${var.environment}z1atw${var.project_app_group}${var.project_prefix}"
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

#----------------------------------
# Resource names module
#----------------------------------

module "resource_names" {
  source            = "../resource_names"
  environment       = var.environment
  project_app_group = var.project_app_group
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  project_ledger    = var.project_ledger
  zone              = var.zone
}

#----------------------------------
# KMS Key names
#----------------------------------

module "data_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "datakey"])
}

module "glue_enc_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "glueenckey"])
}

#----------------------------------
# S3 Bucket names
#----------------------------------

module "s3b_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "datastorage"])
}

module "s3b_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "artifacts"])
}

module "s3b_glue_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "glueartifacts"])
}

module "s3b_athena_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "athena"])
}

#----------------------------------
# Glue names
#----------------------------------

module "glue_db_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "oidhdb"])
}

module "glue_alayasyncdb_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "alayasync"])
}

module "glue_ingest_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "ingestjob"])
}

module "glue_ingest_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "ingestjob"])
}

module "glue_cleaning_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "cleaningjob"])
}

module "glue_cleaning_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "cleaningjob"])
}

module "glue_ind_dedup_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "inddedupjob"])
}

module "glue_ind_dedup_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "inddedupjob"])
}

module "glue_org_dedup_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "orgdedupjob"])
}

module "glue_org_dedup_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "orgdedupjob"])
}

module "glue_getgeoinfo_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "getgeoinfojob"])
}

module "glue_getgeoinfo_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "getgeoinfojob"])
}

#----------------------------------
# Lambda names
#----------------------------------

module "lambda_config_loader_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "configloader"])
}

module "lambda_config_loader_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "configloader"])
}

#----------------------------------
# ECS Role & Policy
#----------------------------------

module "iro_ecs_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayapush"])
}

module "ipl_ecs_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("-", [var.project_prefix, "alayapush"])
}

module "ecr_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ecr"
  purpose     = join("-", [var.project_prefix, "alayapush"])
}

module "iro_ecs_task_execution_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("-", [var.project_prefix, "alayapush","execution"])
}

#----------------------------------
# Alaya Sync names
#----------------------------------

module "sqs_register_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sqs"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

module "sqs_register_dlq_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sqs"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregisterdlq"])
}

# lambdas - register
module "ipl_lambda_register_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

module "iro_lambda_register_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

module "lambda_register_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

# lambdas - schedule
module "ipl_lambda_schedule_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncschedule"])
}

module "iro_lambda_schedule_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncschedule"])
}

module "lambda_schedule_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncschedule"])
}

# lambdas - processing
module "ipl_lambda_processing_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncprocessing"])
}

module "iro_lambda_processing_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncprocessing"])
}

module "lambda_processing_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncprocessing"])
}

# lambdas - reduce
module "ipl_lambda_reduce_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncreduce"])
}

module "iro_lambda_reduce_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncreduce"])
}

module "lambda_reduce_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncreduce"])
}

# lambdas - execution
module "ipl_lambda_execution_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncexecution"])
}

module "iro_lambda_execution_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncexecution"])
}

module "lambda_execution_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncexecution"])
}

# lambdas - ecs_start
module "ipl_lambda_ecs_start_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncecsstart"])
}

module "iro_lambda_ecs_start_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncecsstart"])
}

module "lambda_ecs_start_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncecsstart"])
}

# lambdas - ecs_status
module "ipl_lambda_ecs_status_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncecsstatus"])
}

module "iro_lambda_ecs_status_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncecsstatus"])
}

module "lambda_ecs_status_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncecsstatus"])
}

# dynamo table sync
module "dynamodb_sources_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "dyt"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

# sfn for sync
module "iro_sfn_alayasync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

module "ipl_sfn_alayasync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

module "sfm_alayasync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "stm"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

# cloudwatch alarms #
module "cwa_alaya_sync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwa"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

module "cwa_alaya_sync_register_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwa"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

#----------------------------------
# Aurora Names
#----------------------------------

module "aurora_security_group_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", "admintooldbsecuritygroup"])
}

module "aurora_subnet_group_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "rdu"
  purpose     = join("", [var.project_prefix, "-", "admintooldbsubnetgroup"])
}

module "aurora_cluster_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "rcc"
  purpose     = join("", [var.project_prefix, "-", "admintooldb"])
}

#----------------------------------
# Sfn names
#----------------------------------

module "sfn_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "mainprocess"])
}

module "etl_sfn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "stm"
  purpose     = join("", [var.project_prefix, "-", "mainprocess"])
}

module "trigger_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "etltrigger"])
}

module "cron_trigger_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwr"
  purpose     = join("", [var.project_prefix, "-", "etltrigger"])
}

#----------------------------------
# Policy names
#----------------------------------

module "glue_ingest_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "ingestjob"])
}

module "glue_cleaning_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "cleaningjob"])
}

module "glue_ind_dedup_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "inddedupjob"])
}

module "glue_org_dedup_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "orgdedupjob"])
}

module "glue_getgeoinfo_job_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "getgeoinfojob"])
}

module "lambda_config_loader_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "configloader"])
}

module "elt_sfn_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "mainprocess"])
}

module "cron_trigger_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "etltrigger"])
}

# ------------------------------------------------------------------------------
# Create Role for Dev Account for Deployments
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_dev_deploy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_number_devops}:root"]
    }
  }
}

# ------------------------------------------------------------------------------
# Aurora Deployment
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "aurora_deploy" {

  statement {
    effect = "Allow"
    actions = [
      "rds:ListTagsForResource",
      "rds:AddTagsToResource",
      "rds:DescribeDBClusterParameterGroups",
      "rds:DescribeDBSecurityGroups",
      "rds:CreateDBCluster",
      "rds:DeleteDBCluster",
      "rds:ModifyDBCluster",
      "rds:DescribeDBCluster",
      "rds:ModifyDBClusterParameterGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DescribeDBClusters",
      "rds:DescribeGlobalClusters",
      "rds:AddRoleToDBCluster",
      "rds:CreateDBInstance",
      "rds:DescribeDBInstances",
      "rds:DeleteDBInstance",
      "rds:ModifyDBInstance",
      "rds:AddRoleToDBInstance"
    ]
    resources = [
      "arn:aws:rds:${var.region}:${var.aws_account_number_env}:cluster:${module.aurora_cluster_naming.name}",
      "arn:aws:rds:${var.region}:${var.aws_account_number_env}:subgrp:${module.aurora_subnet_group_naming.name}",
      "arn:aws:rds::${var.aws_account_number_env}:global-cluster:*"
    ]
    sid = "clusterpermissions"
  }
  
  statement {
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:DescribeDBInstances",
      "rds:DeleteDBInstance",
      "rds:ModifyDBInstance",
      "rds:AddRoleToDBInstance",
      "rds:ListTagsForResource",
      "rds:AddTagsToResource"
    ]
    resources = [
      "arn:aws:rds:${var.region}:${var.aws_account_number_env}:db:*"
    ]
    condition {
      test = "StringEquals"
      variable = "rds:db-tag/Name"
      values = ["${module.aurora_cluster_naming.name}"]
    }
    sid = "rdsinstancepermissions"
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:CancelRotateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:ListSecrets"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${var.aws_account_number_env}:secret:*"
    ]
    condition {
      test = "StringEquals"
      variable = "secretsmanager:ResourceTag/aws:rds:primaryDBClusterArn"
      values = ["arn:aws:rds:${var.region}:${var.aws_account_number_env}:cluster:${module.aurora_cluster_naming.name}"]
    }
    sid = "clustersecretpermissions"
  }
}

# ------------------------------------------------------------------------------
# KMS, S3, SSM Policies
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "dev_deploy" {

  statement {
    effect = "Allow"
    actions = [
      "kms:TagResource",
      "kms:DeleteKey",
      "kms:ScheduleKeyDeletion",
      "kms:EnableKey",
      "kms:PutKeyPolicy",
      "kms:GenerateDataKey",
      "kms:EnableKeyRotation",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:DeleteAlias",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
      "kms:Decrypt"
    ]
    resources = [
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:key/*"
    ]
    sid = "kmspermissions"
  }

  statement {
    effect  = "Allow"
    actions = ["kms:DeleteAlias"]
    resources = [
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/${module.data_key_name.name}",
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/${module.glue_enc_key_name.name}"
    ]
    sid = "kmsaliaspermissions"
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:CreateKey", "kms:CreateAlias", "kms:ListAliases"]
    resources = ["*"]
    sid       = "kmscreatepermissions"
  }

  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ecstask"
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    sid       = "iampermissions"
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroupRules"
    ]
    resources = ["*"]
    sid       = "ec2describe"
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteSecurityGroup",
      "ec2:CreateSecurityGroup",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${var.aws_account_number_env}:security-group/*",
      "arn:aws:ec2:${var.region}:${var.aws_account_number_env}:security-group-rule/*",
      "arn:aws:ec2:${var.region}:${var.aws_account_number_env}:vpc/*"
    ]
    sid = "ec2sgcreate"
  }

  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${module.s3b_data_naming.name}",
      "arn:aws:s3:::${module.s3b_data_naming.name}/*",
      "arn:aws:s3:::${module.s3b_artifacts_naming.name}",
      "arn:aws:s3:::${module.s3b_artifacts_naming.name}/*",
      "arn:aws:s3:::${module.s3b_glue_artifacts_naming.name}",
      "arn:aws:s3:::${module.s3b_glue_artifacts_naming.name}/*",
      "arn:aws:s3:::${module.s3b_athena_naming.name}",
      "arn:aws:s3:::${module.s3b_athena_naming.name}/*"
    ]
    sid = "s3permissions"
  }

  statement {
    actions = [
      "logs:DescribeLogGroups"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${var.region}:${var.aws_account_number_env}:log-group::log-stream:*",
      "arn:aws:logs:${var.region}:${var.aws_account_number_env}:log-group:*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
      "logs:ListTagsLogGroup",
      "logs:DeleteLogGroup",
      "logs:TagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${var.region}:${var.aws_account_number_env}:log-group:*:log-stream:*"
    ]
    sid = "cloudwatchlogcreation"
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/${var.project_app_group}/*",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/secure/${var.site}/${var.environment}/${var.project_app_group}/*",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/*",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/secure/${var.site}/${var.environment_devops}/codebuild/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DeleteParameter",
      "ssm:PutParameter",
      "ssm:ListTagsForResource",
      "ssm:AddTagsToResource"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/${var.project_app_group}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryCatalogData",
      "ecr:DeleteRepository",
      "ecr:TagResource",
      "ecr:ListTagsForResource",
      "ecr:PutImageTagMutability"
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${var.aws_account_number_env}:repository/${module.ecr_naming.name}",
      "arn:aws:ecr:${var.region}:${var.aws_account_number_env}:repository/${module.resource_names.ecr_names.addgeoinfo.name}"
    ]
    sid = "ecrrepocreation"
  }
}

# ------------------------------------------------------------------------------
# IAM Role/Policy Permissions
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "dev_deploy2" {

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
      "iam:CreateRole",
      "iam:TagRole",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:DeleteRole",
      "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.glue_cleaning_job_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.glue_ind_dedup_job_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.glue_org_dedup_job_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.glue_getgeoinfo_job_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.lambda_config_loader_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.sfn_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.trigger_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_ecs_task_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_ecs_task_execution_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_register_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_schedule_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_processing_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_reduce_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_execution_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_ecs_start_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_ecs_status_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_sfn_alayasync_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${var.site}${var.environment}${var.zone}iro${var.project_prefix}*"
    ]
    sid = "iamroles"
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:TagPolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion"

    ]
    resources = [
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.glue_ingest_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.glue_cleaning_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.glue_ind_dedup_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.glue_org_dedup_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.glue_getgeoinfo_job_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.lambda_config_loader_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.elt_sfn_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.cron_trigger_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_ecs_task_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_register_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_schedule_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_processing_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_reduce_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_execution_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_ecs_start_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_ecs_status_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_sfn_alayasync_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${var.site}${var.environment}${var.zone}ipl${var.project_prefix}*"
    ]
    sid = "iampolicies"
  }

}

# ------------------------------------------------------------------------------
# ETL Policies
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "dev_deploy3" {
  statement {
    effect  = "Allow"
    actions = ["lambda:*"]
    resources = [
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_config_loader_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:layer:delta_geopy:*",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:layer:delta_geopy",
      "arn:aws:lambda:${var.region}:336392948345:layer:AWSSDKPandas-Python310:*",
      "arn:aws:lambda:${var.region}:336392948345:layer:AWSSDKPandas-Python310"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["states:*"]
    resources = [
      "arn:aws:states:${var.region}:${var.aws_account_number_env}:stateMachine:${module.etl_sfn_naming.name}"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["events:*"]
    resources = [
      "arn:aws:events:${var.region}:${var.aws_account_number_env}:rule/${module.cron_trigger_naming.name}"
    ]
  }

  statement {
    actions = [
      "glue:GetDatabase",
      "glue:UpdateDatabase",
      "glue:DeleteDatabase",
      "glue:CreateDatabase",
      "glue:GetDatabases",
      "glue:CreateConnection",
      "glue:DeleteConnection",
      "glue:GetConnection",
      "glue:UpdateConnection",
      "glue:GetTags",
      "glue:CreateTable",
      "glue:DeleteTable",
      "glue:GetTable"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:database/${module.glue_db_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:userDefinedFunction/${module.glue_db_naming.name}/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:table/${module.glue_db_naming.name}/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:database/${module.glue_alayasyncdb_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:userDefinedFunction/${module.glue_alayasyncdb_naming.name}/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:table/${module.glue_alayasyncdb_naming.name}/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:catalog/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:catalog",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:connection/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:connection",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:connection",
    ]
  }

  statement {
    actions = [
      "glue:GetSecurityConfiguration",
      "glue:CreateSecurityConfiguration",
      "glue:DeleteSecurityConfiguration"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "glue:DeleteJob",
      "glue:CreateJob",
      "glue:UpdateJob",
      "glue:GetJob",
      "glue:GetTags"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:job/${module.glue_ingest_job_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:job/${module.glue_cleaning_job_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:job/${module.glue_ind_dedup_job_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:job/${module.glue_org_dedup_job_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:job/${module.glue_getgeoinfo_job_naming.name}" 
    ]
  }
}

# ------------------------------------------------------------------------------
# Alaya Sync
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "dev_deploy4" {
  statement {
    effect  = "Allow"
    actions = ["lambda:*"]
    resources = [
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_register_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_schedule_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_processing_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_reduce_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_execution_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_ecs_start_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_ecs_status_naming.name}"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["states:*"]
    resources = [
      "arn:aws:states:${var.region}:${var.aws_account_number_env}:stateMachine:${module.sfm_alayasync_naming.name}"
    ]
    sid = "statessync"
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:DeleteEventSourceMapping",
      "lambda:UpdateEventSourceMapping",
      "lambda:CreateEventSourceMapping",
      "lambda:ListEventSourceMappings",
      "lambda:GetEventSourceMapping"
    ]
    resources = ["*"]
    sid       = "sourcemappingsync"
  }

  statement {
    effect = "Allow"
    actions = [
      "sqs:createqueue",
      "sqs:getqueueattributes",
      "sqs:deletequeue",
      "sqs:tagqueue",
      "sqs:setqueueattributes",
      "sqs:listqueuetags"
    ]
    resources = [
      "arn:aws:sqs:${var.region}:${var.aws_account_number_env}:${module.sqs_register_data_naming.name}",
      "arn:aws:sqs:${var.region}:${var.aws_account_number_env}:${module.sqs_register_dlq_data_naming.name}"
    ]
    sid = "sqssync"
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:Delete*",
      "dynamodb:Describe*",
      "dynamodb:TagResource",
      "dynamodb:List*",
      "dynamodb:UpdateTimeToLive"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.aws_account_number_env}:table/${module.dynamodb_sources_naming.name}"
    ]
    sid = "dynamosync"
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:DeleteAlarms"
    ]
    resources = [
      "arn:aws:cloudwatch:${var.region}:${var.aws_account_number_env}:alarm:${module.cwa_alaya_sync_naming.name}",
      "arn:aws:cloudwatch:${var.region}:${var.aws_account_number_env}:alarm:${module.cwa_alaya_sync_register_naming.name}"
    ]
    sid = "cloudwatchalarms"
  }

  statement {
    effect = "Allow"
    actions = [
      "athena:CreateWorkGroup",
      "athena:TagResource",
      "athena:DeleteWorkGroup",
      "athena:GetWorkGroup",
      "athena:ListTagsForResource"
    ]
    resources = [
      "arn:aws:athena:${var.region}:${var.aws_account_number_env}:workgroup/${local.athena_workgroup}"
    ]
  }
}
# ------------------------------------------------------------------------------
# Deployment role policy attachements
# ------------------------------------------------------------------------------

module "irp_aurora_deployment_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["auroradeploy", var.project_prefix])
}

module "irp_dev_deployment_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment", var.project_prefix])
}

module "irp_dev_deployment_naming2" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment2", var.project_prefix])
}

module "irp_dev_deployment_naming3" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment3", var.project_prefix])
}

module "irp_dev_deployment_naming4" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment4", var.project_prefix])
}

module "iro_dev_deployment_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.irp_dev_deployment_naming
  type        = "iro"
}

resource "aws_iam_role" "dev_deployment" {
  name               = module.iro_dev_deployment_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume_dev_deploy.json
  tags               = module.iro_dev_deployment_naming.tags
}

resource "aws_iam_policy" "aurora_deployment" {
  name   = module.irp_aurora_deployment_naming.name
  policy = data.aws_iam_policy_document.aurora_deploy.json
}

resource "aws_iam_policy" "dev_deployment" {
  name   = module.irp_dev_deployment_naming.name
  policy = data.aws_iam_policy_document.dev_deploy.json
}

resource "aws_iam_policy" "dev_deployment2" {
  name   = module.irp_dev_deployment_naming2.name
  policy = data.aws_iam_policy_document.dev_deploy2.json
}

resource "aws_iam_policy" "dev_deployment3" {
  name   = module.irp_dev_deployment_naming3.name
  policy = data.aws_iam_policy_document.dev_deploy3.json
}

resource "aws_iam_policy" "dev_deployment4" {
  name   = module.irp_dev_deployment_naming4.name
  policy = data.aws_iam_policy_document.dev_deploy4.json
}

resource "aws_iam_role_policy_attachment" "aurora_deployment" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.aurora_deployment.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment2" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment2.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment3" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment3.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment4" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment4.arn
}
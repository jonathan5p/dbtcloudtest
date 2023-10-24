data "aws_region" "current" {}

module "lambda_alaya_sync_scheduling" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.6"

  environment       = var.environment
  lambda_name       = "alayasyncschedule"
  lambda_path       = "../src/alayasync/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone
  runtime           = "python3.10"

  policy_variables = var.project_objects

  environment_variables = {
    "OIDH_TABLE"          = var.project_objects.dynamo_table_register
    "ATHENA_BUCKET"       = var.project_objects.athena_bucket_id
    "PAYLOAD_BUCKET"      = var.project_objects.artifacts_bucket_id
    "PAYLOAD_TRIGGER_KEY" = join("/", [var.project_objects.payload_trigger_key, "schedule_executions"])
  }

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python310:4"
  ]
}

module "lambda_alaya_sync_reduce" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

  environment       = var.environment
  lambda_name       = "alayasyncreduce"
  lambda_path       = "../src/alayasync/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  policy_variables = var.project_objects

  environment_variables = {
    "OIDH_TABLE" = var.project_objects.dynamo_table_register
  }
}

module "lambda_alaya_sync_ecs_start" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

  environment       = var.environment
  lambda_name       = "alayasyncecsstart"
  lambda_path       = "../src/alayasync/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  policy_variables = merge(var.project_objects, { "gethubids_lambda" = module.lambda_get_hubids.lambda_arn })

  environment_variables = {
    "OIDH_TABLE"         = var.project_objects.dynamo_table_register
    "OIDH_TASK_FUNCTION" = module.lambda_get_hubids.lambda_arn
  }
}


module "lambda_alaya_sync_ecs_status" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

  environment       = var.environment
  lambda_name       = "alayasyncecsstatus"
  lambda_path       = "../src/alayasync/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  policy_variables = var.project_objects

  environment_variables = {
    "OIDH_TABLE"  = var.project_objects.dynamo_table_register
    "ECS_CLUSTER" = var.project_objects.ecs_cluster
  }
}

module "lambda_get_hubids" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

  environment       = var.environment
  lambda_name       = "gethubids"
  lambda_path       = "../src/alayasync/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  policy_variables = var.project_objects
}
data "aws_region" "current" {}

module "lambda_alaya_sync_register" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

  environment       = var.environment
  lambda_name       = "alayasyncregister"
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
  runtime           = "python3.9"

  policy_variables = var.project_objects

  environment_variables = {
    "ATHENA_BUCKET" = var.project_objects.athena_bucket_id
    "INDIVIDUALS"     = var.project_objects.individuals
    "LAMBDA_CHATBOT" = var.project_objects.lambda_chatbot_arn
    "OIDH_TABLE"    = var.project_objects.dynamo_table_register
    "ORGANIZATIONS"   = var.project_objects.organizations
  }

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python39:10",
    var.project_objects.alaya_sync_layer
    #"arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python310:4"
  ]
}

#module "lambda_alaya_sync_processing" {
#  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

#  environment       = var.environment
#  lambda_name       = "alayasyncprocessing"
#  lambda_path       = "../src/alayasync/lambda"
#  project_app_group = var.project_app_group
#  project_ledger    = var.project_ledger
#  project_prefix    = var.project_prefix
#  site              = var.site
#  tier              = var.tier
#  zone              = var.zone

#  policy_variables = var.project_objects

#  environment_variables = {
#    "OIDH_TABLE" = var.project_objects.dynamo_table_register
#  }
#}

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
    "LAMBDA_CHATBOT" = var.project_objects.lambda_chatbot_arn
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

  policy_variables = merge(var.project_objects, {
    "alaya_sync_async" = module.lambda_alaya_sync_async.lambda_arn
  })

  environment_variables = {
    "OIDH_TABLE"      = var.project_objects.dynamo_table_register
    "ECS_CLUSTER"     = var.project_objects.ecs_cluster
    "TASK_DEFINITION" = var.project_objects.task_definition
    "ECS_SUBNETS"     = var.project_objects.ecs_subnets
    "FUNCTION_NAME"   = module.lambda_alaya_sync_async.lambda_arn
    "INDIVIDUALS"     = var.project_objects.individuals
    "ORGANIZATIONS"   = var.project_objects.organizations
    "STATE_TABLE"     = var.project_objects.dynamo_table_async
    "TTL_DAYS"        = var.project_objects.ttl_days_async
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
    "STATE_TABLE" = var.project_objects.dynamo_table_async
  }
}


module "lambda_alaya_sync_async" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.6"

  environment       = var.environment
  lambda_name       = "alayasyncasync"
  lambda_path       = "../src/alayasync/lambda"
  memory_size       = 512
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  timeout           = 900
  zone              = var.zone

  policy_variables = var.project_objects

  environment_variables = {
    "ATHENA_BUCKET" = var.project_objects.athena_bucket_id
    "OIDH_TABLE"    = var.project_objects.dynamo_table_register
    "STATE_TABLE"   = var.project_objects.dynamo_table_async
    "TIMEOUT"       = var.project_objects.async_lambda_timeout
    "TTL_DAYS"      = var.project_objects.ttl_days_async
  }

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python39:10",
    var.project_objects.alaya_utils_layer,
    var.project_objects.alaya_sync_layer
  ]
}
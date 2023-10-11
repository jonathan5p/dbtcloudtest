data "aws_region" "current" {}

module "lambda_alaya_sync_register" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"
    
    environment         = var.environment
    lambda_name         = "alayasyncregister"
    lambda_path         = "../src/alayasync/lambda"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables = var.project_objects
    
    environment_variables = {
      "OIDH_TABLE" = var.project_objects.dynamo_table_register
    }
}

module "lambda_alaya_sync_scheduling" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.6"

    environment         = var.environment
    lambda_name         = "alayasyncschedule"
    lambda_path         = "../src/alayasync/lambda"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone
    runtime             = "python3.10"

    policy_variables = var.project_objects
    
    environment_variables = {
      "OIDH_TABLE" = var.project_objects.dynamo_table_register
      "ATHENA_BUCKET" = var.project_objects.athena_bucket_id
    }

    layers = [
      "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python310:4"
    ]
}

module "lambda_alaya_sync_processing" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

    environment         = var.environment
    lambda_name         = "alayasyncprocessing"
    lambda_path         = "../src/alayasync/lambda"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables = var.project_objects
    
    environment_variables = {
      "OIDH_TABLE" = var.project_objects.dynamo_table_register
    }
}

module "lambda_alaya_sync_reduce" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

    environment         = var.environment
    lambda_name         = "alayasyncreduce"
    lambda_path         = "../src/alayasync/lambda"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables = var.project_objects
    
    environment_variables = {
      "OIDH_TABLE" = var.project_objects.dynamo_table_register
    }
}

module "lambda_alaya_sync_ecs_start" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

    environment         = var.environment
    lambda_name         = "alayasyncecsstart"
    lambda_path         = "../src/alayasync/lambda"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables = var.project_objects
    
    environment_variables = {
      "OIDH_TABLE" = var.project_objects.dynamo_table_register
      "ECS_CLUSTER"= var.project_objects.ecs_cluster
      "TASK_DEFINITION"= var.project_objects.task_definition
      "ECS_SUBNETS" = var.project_objects.ecs_subnets
      "INDIVIDUALS" = var.project_objects.individuals
      "ORGANIZATIONS" = var.project_objects.organizations
  }
}


module "lambda_alaya_sync_ecs_status" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

    environment         = var.environment
    lambda_name         = "alayasyncecsstatus"
    lambda_path         = "../src/alayasync/lambda"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables = var.project_objects
    
    environment_variables = {
      "OIDH_TABLE" = var.project_objects.dynamo_table_register
      "ECS_CLUSTER" = var.project_objects.ecs_cluster
    }
}
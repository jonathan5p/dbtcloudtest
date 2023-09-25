module "lambda_alaya_sync_register" {
    #source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"
    source = "../../../modules/lambdas"

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
    #source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"
    source = "../../../modules/lambdas"

    environment         = var.environment
    lambda_name         = "alayasyncschedule"
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

module "lambda_alaya_sync_processing" {
    #source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"
    source = "../../../modules/lambdas"

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
    #source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"
    source = "../../../modules/lambdas"

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
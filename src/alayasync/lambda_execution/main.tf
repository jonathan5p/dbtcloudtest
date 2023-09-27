module "lambda_alaya_sync_execution" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.4"

    environment         = var.environment
    lambda_name         = "alayasyncexecution"
    lambda_path         = "../src/alayasync/lambda_execution"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables = var.project_objects
    
    environment_variables = {
      "SFN" = var.project_objects.sfn_alaya_sync
    }
}
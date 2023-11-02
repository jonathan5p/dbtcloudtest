data "aws_region" "current" {}

#------------------------------------------------------------------------------
# Lambda functions
#------------------------------------------------------------------------------

module "lambda_config_loader" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=v0.0.6"

  environment       = var.environment
  lambda_name       = "configloader"
  lambda_path       = "../src/mainprocess/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone
  runtime           = "python3.10"

  policy_variables = var.project_objects
}
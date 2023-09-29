data "aws_region" "current" {}

#------------------------------------------------------------------------------
# Caar deltalake+geopy layer
#------------------------------------------------------------------------------

resource "aws_lambda_layer_version" "delta_geopy_layer" {
  filename            = "../src/mainprocess/lambda/layers/delta_geopy.zip"
  layer_name          = "delta_geopy"
  compatible_runtimes = ["python3.10", "python3.9"]
}

#------------------------------------------------------------------------------
# Lambda functions
#------------------------------------------------------------------------------

module "lambda_config_loader" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"

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

  environment_variables = {
    "ARTIFACTS_BUCKET" = var.project_objects.artifacts_bucket_id
    "ETL_CONFIG_KEY"   = "config/ingest_config.json"
  }
}

module "lambda_staging_agent" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"

  environment       = var.environment
  lambda_name       = "enrichagent"
  lambda_path       = "../src/mainprocess/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone
  timeout           = 900
  memory_size       = 2048
  runtime           = "python3.10"

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python310:4",
    aws_lambda_layer_version.delta_geopy_layer.arn
  ]

  policy_variables = var.project_objects

  environment_variables = {
    "S3_SOURCE_PATH" = "s3://${var.project_objects.data_bucket_id}/raw_data/${var.project_objects.gluedb_name}/${var.project_objects.lambda_ec_agent_source_table_name}/"
    "S3_TARGET_PATH" = "s3://${var.project_objects.data_bucket_id}/staging_data/${var.project_objects.gluedb_name}/${var.project_objects.lambda_ec_agent_target_table_name}/"
  }
}

module "lambda_staging_office" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//lambdas?ref=dev"

  environment       = var.environment
  lambda_name       = "enrichoffice"
  lambda_path       = "../src/mainprocess/lambda"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone
  timeout           = 900
  memory_size       = 2048
  runtime           = "python3.10"

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python310:4",
    aws_lambda_layer_version.delta_geopy_layer.arn
  ]

  policy_variables = var.project_objects

  environment_variables = {
    "S3_SOURCE_PATH" = "s3://${var.project_objects.data_bucket_id}/raw_data/${var.project_objects.gluedb_name}/${var.project_objects.lambda_ec_office_source_table_name}/"
    "S3_TARGET_PATH" = "s3://${var.project_objects.data_bucket_id}/staging_data/${var.project_objects.gluedb_name}/${var.project_objects.lambda_ec_office_target_table_name}/"
  }
}
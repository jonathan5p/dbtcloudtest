locals {
  athena_workgroup = "${var.site}${var.environment}z1atw${var.project_app_group}${var.project_prefix}"
  tags = {
    app          = var.project_app_group
    env          = var.environment
    ledger       = var.project_ledger
    site         = var.site
    tier         = var.tier
    zone         = var.zone
    creation_app = "terraform"
  }
}

module "athena_bucket" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//s3?ref=v0.0.6"

  environment       = var.environment
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  suffix_name       = "athena"
  site              = var.site
  tier              = var.tier
  zone              = var.zone

}

resource "aws_athena_workgroup" "workgroup" {
  name = local.athena_workgroup
  tags = local.tags

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${module.athena_bucket.bucket_id}"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
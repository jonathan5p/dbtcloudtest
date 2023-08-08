module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

# ------------------------------------------------------------------------------
# Create Code Bucket
# ------------------------------------------------------------------------------
module "s3b_output_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = var.project_prefix
}

resource "aws_s3_bucket" "output" {
  bucket = module.s3b_output_naming.name
  acl    = "private"
  tags   = module.s3b_output_naming.tags
}

resource "aws_ssm_parameter" "code_bucket_arn" {
  name        = "/${var.datapipeline_name}/s3/code_bucket_arn"
  type        = "SecureString"
  value       = aws_s3_bucket.output.arn
  description = "Arn for the code bucket datapipeline"
  overwrite   = true
}

resource "aws_ssm_parameter" "code_bucket" {
  name        = "/${var.datapipeline_name}/s3/code_bucket"
  type        = "SecureString"
  value       = aws_s3_bucket.output.bucket
  description = "Name for the code bucket datapipeline"
  overwrite   = true
}
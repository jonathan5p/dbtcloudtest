provider "aws" {
  region = var.region[var.site]
  assume_role {
    role_arn     = var.role_arn
    session_name = "oidh"
  }
}

data "aws_caller_identity" "current" {}

locals {
  lambda_runtime = "python3.10"
  lambda_handler = "lambda_function.lambda_handler"
}

data "aws_region" "current" {}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

#------------------------------------------------------------------------------
# KMS Keys for the S3 Buckets and Glue
#------------------------------------------------------------------------------

# OIDH Dedup Process Encryption Key
module "data_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "datakey"])
}
module "data_key" {
  source             = "../modules/kms"
  key_name           = module.data_key_name.name
  key_tags           = module.data_key_name.tags
  key_description    = "KMS key used for data encryption of all the data in the datahub-dedup process"
  aws_account_number = data.aws_caller_identity.current.account_id
}

# Glue Data Encryption Key
module "glue_enc_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "glueenckey"])
}
module "glue_enc_key" {
  source             = "../modules/kms"
  key_name           = module.glue_enc_key_name.name
  key_tags           = module.glue_enc_key_name.tags
  key_description    = "KMS key used for data encryption of all the glue resources used in the datahub-dedup process"
  aws_account_number = data.aws_caller_identity.current.account_id
}

#------------------------------------------------------------------------------
# S3 Buckets
#------------------------------------------------------------------------------

# Data Bucket
module "s3b_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "datastorage"])
}

module "s3_data_bucket" {
  source                            = "../modules/s3"
  s3_bucket                         = module.s3b_data_naming.name
  s3_bucket_tags                    = module.s3b_data_naming.tags
  s3_bucket_key_id                  = module.data_key.key_id
  s3_bucket_key_arn                 = module.data_key.key_arn
  s3_bucket_tmp_expiration_days     = var.s3_bucket_tmp_expiration_days
  s3_bucket_objects_expiration_days = var.s3_bucket_objects_expiration_days
  s3_bucket_objects_transition_days = var.s3_bucket_objects_transition_days
}

# Artifacts Bucket
module "s3b_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "artifacts"])
}

module "s3_artifacts_bucket" {
  source                            = "../modules/s3"
  s3_bucket                         = module.s3b_artifacts_naming.name
  s3_bucket_tags                    = module.s3b_artifacts_naming.tags
  s3_bucket_key_id                  = module.data_key.key_id
  s3_bucket_key_arn                 = module.data_key.key_arn
  s3_bucket_tmp_expiration_days     = var.s3_bucket_tmp_expiration_days
  s3_bucket_objects_expiration_days = var.s3_bucket_objects_expiration_days
  s3_bucket_objects_transition_days = var.s3_bucket_objects_transition_days
}

# Glue Bucket
module "s3b_glue_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "glueartifacts"])
}

module "s3_glue_artifacts_bucket" {
  source                            = "../modules/s3"
  s3_bucket                         = module.s3b_glue_artifacts_naming.name
  s3_bucket_tags                    = module.s3b_glue_artifacts_naming.tags
  s3_bucket_key_id                  = module.glue_enc_key.key_id
  s3_bucket_key_arn                 = module.glue_enc_key.key_arn
  s3_bucket_tmp_expiration_days     = var.s3_bucket_tmp_expiration_days
  s3_bucket_objects_expiration_days = var.s3_bucket_objects_expiration_days
  s3_bucket_objects_transition_days = var.s3_bucket_objects_transition_days
}

#------------------------------------------------------------------------------
# S3 Data
#------------------------------------------------------------------------------

resource "aws_s3_object" "artifacts" {
  bucket                 = module.s3_artifacts_bucket.bucket_id
  for_each               = fileset("../src/artifacts/", "**")
  key                    = each.value
  source                 = "../src/artifacts/${each.value}"
  server_side_encryption = "aws:kms"
  bucket_key_enabled     = true
}

resource "aws_s3_object" "glue_artifacts" {
  bucket                 = module.s3_glue_artifacts_bucket.bucket_id
  for_each               = fileset("../src/glue/", "**")
  key                    = each.value
  source                 = "../src/glue/${each.value}"
  server_side_encryption = "aws:kms"
  bucket_key_enabled     = true
}
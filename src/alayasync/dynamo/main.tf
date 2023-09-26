module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

module "dynamodb_sources_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "dyt"
  purpose     = join("", [var.project_prefix, "-", var.table_name])
}

resource "aws_dynamodb_table" "metadata" {

    name             = module.dynamodb_sources_naming.name
    billing_mode     = "PAY_PER_REQUEST"
    hash_key         = "id"
    stream_enabled   = true
    stream_view_type = "NEW_AND_OLD_IMAGES"
    tags             = module.dynamodb_sources_naming.tags
  
    attribute {
      name = "id"
      type = "S"
    }
  
    attribute {
      name = "batch"
      type = "S"
    }
  
    attribute {
      name = "status"
      type = "S"
    }
  
    global_secondary_index {
      name            = "scheduling-index"
      hash_key        = "batch"
      range_key       = "status"  
      projection_type = "ALL"
    }
  
    server_side_encryption {
      enabled     = true
      kms_key_arn = var.project_objects.data_key_arn
    }
  }
  
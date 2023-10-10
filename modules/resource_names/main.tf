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
# Mainprocess ECR Configuration
#------------------------------------------------------------------------------

module "addgeoinfo_ecr_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ecr"
  purpose     = join("", [var.project_prefix, "-addgeoinfo"])
}
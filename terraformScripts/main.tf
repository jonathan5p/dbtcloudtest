provider "aws" {
  region = var.region[var.site]
  assume_role {
    role_arn     = var.role_arn
    session_name = "oidh"
  }
}

data "aws_region" "current" {}

resource "aws_ssm_parameter" "foo" {
  name  = "foo"
  type  = "String"
  value = "bar"
}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}
module "individuals" {
  source = "./table"

  environment       = var.environment
  table_name        = "individuals"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  project_objects = var.project_objects

}


module "organizations" {
  source = "./table"

  environment       = var.environment
  table_name        = "organizations"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  project_objects = var.project_objects

}
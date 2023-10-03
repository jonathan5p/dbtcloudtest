module "athena_bucket" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//s3?red=s3_add"
    
    environment         = var.environment
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    suffix_name         = "athena"
    site                = var.site
    tier                = var.tier
    zone                = var.zone

}
module "ecs_alaya_sync" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//ecs?ref=v0.0.9"
    
    environment         = var.environment
    task_path         = "../src/alayasync/ecs"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    task_purpose        = "alayapush"
    tier                = var.tier
    zone                = var.zone

    project_objects = var.project_objects

}
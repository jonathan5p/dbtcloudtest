module "alaya_sync_sfn" {
    source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//step_functions?ref=v0.0.4"

    environment         = var.environment
    sfn_name            = "alayasync"
    sfn_path            = "../src/alayasync/stepfunction"
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables   = var.policy_variables

}

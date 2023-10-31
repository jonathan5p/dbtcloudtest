#------------------------------------------------------------------------------
# Resource Names
#------------------------------------------------------------------------------

module "resource_names" {
  source            = "../../modules/resource_names"
  environment       = var.environment
  project_app_group = var.project_app_group
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  project_ledger    = var.project_ledger
  zone              = var.zone
}

#------------------------------------------------------------------------------
# Resources
#------------------------------------------------------------------------------

module "aurora_db" {
  source            = "./aurora"
  base_naming       = var.base_naming
  environment       = var.environment
  project_app_group = var.project_app_group
  project_prefix    = var.project_prefix
  site              = var.site
  project_objects   = var.project_objects
}

module "glue_resources" {
  source             = "./glue"
  base_naming        = var.base_naming
  environment        = var.environment
  environment_devops = var.environment_devops
  project_app_group  = var.project_app_group
  project_ledger     = var.project_ledger
  project_prefix     = var.project_prefix
  site               = var.site
  tier               = var.tier
  zone               = var.zone
  project_objects = merge(var.project_objects, { "aurora_jdbc_url" = module.aurora_db.jdbc_url,
  "aurora_subnetid" = module.aurora_db.subnetid })
}

module "lambda_resources" {
  source             = "./lambda"
  base_naming        = var.base_naming
  environment        = var.environment
  environment_devops = var.environment_devops
  project_app_group  = var.project_app_group
  project_ledger     = var.project_ledger
  project_prefix     = var.project_prefix
  site               = var.site
  tier               = var.tier
  zone               = var.zone
  project_objects    = merge(var.project_objects, { "gluedb_name" = module.glue_resources.functions_mapping.gluedb_name })
}

module "stepfunction" {
  source               = "./stepfunction"
  base_naming          = var.base_naming
  environment          = var.environment
  environment_devops   = var.environment_devops
  project_app_group    = var.project_app_group
  project_ledger       = var.project_ledger
  project_prefix       = var.project_prefix
  site                 = var.site
  tier                 = var.tier
  zone                 = var.zone
  cron_schedule        = var.project_objects.cron_schedule
  cron_trigger_enabled = var.project_objects.cron_trigger_enabled

  policy_variables = {
    "glue_ingest_job"      = module.glue_resources.functions_mapping.ingestjob.job_id
    "glue_cleaning_job"    = module.glue_resources.functions_mapping.cleaningjob.job_id
    "glue_ind_dedup_job"   = module.glue_resources.functions_mapping.inddedupjob.job_id
    "glue_org_dedup_job"   = module.glue_resources.functions_mapping.orgdedupjob.job_id
    "glue_geoinfo_job"     = module.glue_resources.functions_mapping.geojob.job_id
    "config_loader_lambda" = module.lambda_resources.functions_mapping.config_loader.lambda_arn
    "data_key_arn"         = var.project_objects.data_key_arn
  }
}

#------------------------------------------------------------------------------
# Glue Aurora Connection
#------------------------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "glue_sg_egress" {
  security_group_id            = module.glue_resources.glue_conn_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535
  referenced_security_group_id = module.aurora_db.sg_id
}

resource "aws_vpc_security_group_ingress_rule" "aurora_sg_ingress" {
  security_group_id            = module.aurora_db.sg_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = module.glue_resources.glue_conn_sg_id
}

#------------------------------------------------------------------------------
# ECR Configuration
#------------------------------------------------------------------------------

resource "aws_ecr_repository" "addgeoinfo" {
  name                 = module.resource_names.ecr_names.addgeoinfo.name
  image_tag_mutability = "MUTABLE"
  tags                 = module.resource_names.ecr_names.addgeoinfo.tags
}

resource "aws_ssm_parameter" "repository_url" {
  name  = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/ecr_addgeoinfo_repository_url"
  type  = "String"
  value = aws_ecr_repository.addgeoinfo.repository_url
}

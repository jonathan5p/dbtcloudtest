data "aws_region" "current" {}

locals {
  db_name = "dev"
  db_port = 5432
}

#------------------------------------------------------------------------------
# Aurora Credentials
#------------------------------------------------------------------------------

data "aws_ssm_parameter" "aurora_vpc_id" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/aurora/vpcid"
}

#------------------------------------------------------------------------------
# Aurora Security Group
#------------------------------------------------------------------------------

module "aurora_security_group_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", "admintooldbsecuritygroup"])
}

resource "aws_security_group" "db_sg" {
  name   = module.aurora_security_group_naming.name
  tags   = module.aurora_security_group_naming.tags
  vpc_id = data.aws_ssm_parameter.aurora_vpc_id.value
}

#------------------------------------------------------------------------------
# Aurora Subnet Group
#------------------------------------------------------------------------------

data "aws_subnets" "db_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.aurora_vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["*mtxdatabase"]
  }
}

module "aurora_subnet_group_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "rdu"
  purpose     = join("", [var.project_prefix, "-", "admintooldbsubnetgroup"])
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = module.aurora_subnet_group_naming.name
  tags       = module.aurora_subnet_group_naming.tags
  subnet_ids = data.aws_subnets.db_subnets.ids
}

#------------------------------------------------------------------------------
# Aurora Cluster
#------------------------------------------------------------------------------

module "aurora_cluster_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "rcc"
  purpose     = join("", [var.project_prefix, "-", "admintooldb"])
}

module "aurora_cluster_final_snapshot_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "rdn"
  purpose     = join("", [var.project_prefix, "-", "admintooldbfinalsnapshot"])
}

resource "aws_rds_cluster" "admintooldb" {
  cluster_identifier              = module.aurora_cluster_naming.name
  tags                            = module.aurora_cluster_naming.tags
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = "13.10"
  database_name                   = local.db_name
  master_username                 = "postgres"
  db_subnet_group_name            = resource.aws_db_subnet_group.db_subnet_group.id
  manage_master_user_password     = true
  backup_retention_period         = var.project_objects.aurora_backup_retention_period
  copy_tags_to_snapshot           = true
  preferred_backup_window         = var.project_objects.aurora_preferred_backup_window
  deletion_protection             = true
  enabled_cloudwatch_logs_exports = toset(["postgresql"])
  final_snapshot_identifier       = module.aurora_cluster_final_snapshot_naming.name
  storage_encrypted               = true
  kms_key_id                      = var.project_objects.data_key_arn

  serverlessv2_scaling_configuration {
    max_capacity = var.project_objects.aurora_max_capacity
    min_capacity = var.project_objects.aurora_min_capacity
  }

  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

resource "aws_rds_cluster_instance" "example" {
  cluster_identifier         = aws_rds_cluster.admintooldb.id
  instance_class             = "db.serverless"
  engine                     = aws_rds_cluster.admintooldb.engine
  engine_version             = aws_rds_cluster.admintooldb.engine_version
  auto_minor_version_upgrade = false
  tags                       = module.aurora_cluster_naming.tags
}


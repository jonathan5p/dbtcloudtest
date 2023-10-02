data "aws_region" "current" {}

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

  ingress {
    description     = "Allow traffic from OIDH glue connection"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.project_objects.aurora_conn_sg_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
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
  engine_version                  = "13.6"
  database_name                   = "dev"
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
  cluster_identifier = aws_rds_cluster.admintooldb.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.admintooldb.engine
  engine_version     = aws_rds_cluster.admintooldb.engine_version
  tags               = module.aurora_cluster_naming.tags
}

#------------------------------------------------------------------------------
# Register Parameters 
#------------------------------------------------------------------------------

resource "aws_ssm_parameter" "aurora_jdbc_url" {
  name  = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/aurora/jdbc_url"
  type  = "String"
  value = "jdbc:postgresql://${aws_rds_cluster.admintooldb.endpoint}:5432/dev"
}

resource "aws_ssm_parameter" "aurora_subnetid" {
  name  = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/aurora/subnetid"
  type  = "String"
  value = data.aws_subnets.db_subnets.ids[0]
}


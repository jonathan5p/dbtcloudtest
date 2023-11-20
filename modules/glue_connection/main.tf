locals {
  connection_properties = {
    JDBC_CONNECTION_URL = var.jdbc_url
    PASSWORD            = var.password
    USERNAME            = var.username
  }
  sg_cond = length(var.security_group_id_list) == 0
}

data "aws_subnet" "connection_subnet" {
  id = var.subnet_id
}

#------------------------------------------------------------------------------
# Glue Connection Security Group
#------------------------------------------------------------------------------

module "conn_sg_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", var.conn_name])
}

resource "aws_security_group" "conn_sg" {
  count  = local.sg_cond ? 1 : 0
  name   = module.conn_sg_naming.name
  tags   = module.conn_sg_naming.tags
  vpc_id = data.aws_subnet.connection_subnet.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "glue_sg_ingress" {
  count                        = local.sg_cond ? 1 : 0
  security_group_id            = aws_security_group.conn_sg[0].id
  ip_protocol                  = -1
  referenced_security_group_id = aws_security_group.conn_sg[0].id
}

resource "aws_vpc_security_group_egress_rule" "glue_sg_egress" {
  count             = local.sg_cond ? 1 : 0
  security_group_id = aws_security_group.conn_sg[0].id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}

#------------------------------------------------------------------------------
# Glue Connection
#------------------------------------------------------------------------------

module "glue_conn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "glx"
  purpose     = join("", [var.project_prefix, "-", var.conn_name])
}

resource "aws_glue_connection" "glue_connection" {
  connection_type       = var.connection_type
  name                  = module.glue_conn_naming.name
  tags                  = module.glue_conn_naming.tags
  connection_properties = var.connection_type == "NETWROK" ? {} : local.connection_properties
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.connection_subnet.availability_zone
    subnet_id              = data.aws_subnet.connection_subnet.id
    security_group_id_list = local.sg_cond ? [aws_security_group.conn_sg[0].id] : var.security_group_id_list
  }
}
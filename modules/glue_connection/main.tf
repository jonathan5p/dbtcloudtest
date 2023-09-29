module "glue_conn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "glx"
  purpose     = join("", [var.project_prefix, "-", var.conn_name])
}

data "aws_subnet" "connection_subnet" {
  id = var.subnet_id
}

resource "aws_glue_connection" "glue_connection" {
  connection_type = "JDBC"
  name            = module.glue_conn_naming.name
  tags            = module.glue_conn_naming.tags
  connection_properties = {
    JDBC_CONNECTION_URL = var.jdbc_url
    PASSWORD            = var.password
    USERNAME            = var.username
  }
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.connection_subnet.availability_zone
    subnet_id              = data.aws_subnet.connection_subnet.id
    security_group_id_list = var.security_group_id_list
  }
}
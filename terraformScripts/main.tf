provider "aws" {
  region = var.region[var.site]
  assume_role {
    role_arn     = var.role_arn
    session_name = "oidh"
  }
}


resource "aws_ssm_parameter" "foo" {
  name  = "foo"
  type  = "String"
  value = "bar"
}

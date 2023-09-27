data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  local_objects = {
    "region" : "${data.aws_region.current.name}"
    "account_id" : "${data.aws_caller_identity.current.account_id}"
  }
}

#------------------------------------------------------------------------------
# Glue Job Role
#------------------------------------------------------------------------------
module "glue_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", var.purpose, "role"])
}

resource "aws_iam_role" "glue_job_role" {
  name = module.glue_job_role_naming.name
  tags = module.glue_job_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "GlueAssumeRole"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

module "iro_glue_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", var.purpose])
}

module "ipl_glue_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", var.purpose])
}

resource "aws_iam_role_policy_attachment" "glue_service_policy_attachement" {
  role       =  aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "template_file" "policy" {
  template = file("${var.glue_path}/${var.purpose}.json.tpl")
  vars = merge(var.policy_variables, local.local_objects)
}

resource "aws_iam_policy" "policy" {
  name   = module.ipl_glue_policy_naming.name
  policy = data.template_file.policy.rendered
}

resource "aws_iam_role_policy_attachment" "glue" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = aws_iam_policy.policy.arn
}
#------------------------------------------------------------------------------
# Glue Job
#------------------------------------------------------------------------------

module "glue_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", var.purpose])
}

resource "aws_glue_job" "glue_job" {
  name                   = module.glue_job_naming.name
  tags                   = module.glue_job_naming.tags
  role_arn               = aws_iam_role.glue_job_role.arn
  glue_version           = "4.0"
  worker_type            = var.worker_type
  timeout                = var.timeout
  security_configuration = var.security_config_id
  number_of_workers      = var.number_of_workers
  connections            = var.connections
  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-job-insights"              = "true"
    "--enable-metrics"                   = "true"
    "--enable-auto-scaling"              = "true"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-glue-datacatalog"          = "true"
    "--conf"                             = var.job_conf,
    "--class"                            = "GlueApp"
    "--extra-jars"                       = var.extra_jars
    "--extra-py-files"                   = var.extra_py_files
  }
  command {
    name            = "glueetl"
    script_location = var.script_location
  }
  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }
}
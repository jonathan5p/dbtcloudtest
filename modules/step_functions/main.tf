data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  local_objects = {
    "region" : "${data.aws_region.current.name}"
    "account_id" : "${data.aws_caller_identity.current.account_id}"
  }
}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

module "iro_sfn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", var.sfn_name])
}

module "ipl_sfn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", var.sfn_name])
}

resource "aws_iam_role" "sfn" {
  name               = module.iro_sfn_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = module.iro_sfn_naming.tags
}

data "template_file" "policy" {
  template = file("${var.sfn_path}/${var.sfn_name}/policy.json.tpl")
  vars = merge(var.policy_variables, local.local_objects,
    {
      "sfn_name" = "${module.sfn_naming.name}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "sfn" {
  role       = aws_iam_role.sfn.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_policy" "policy" {
  name   = module.ipl_sfn_naming.name
  policy = data.template_file.policy.rendered
  tags   = module.ipl_sfn_naming.tags
}

module "sfn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "stm"
  purpose     = join("", [var.project_prefix, "-", var.sfn_name])
}

resource "aws_sfn_state_machine" "sfn" {
  name       = module.sfn_naming.name
  role_arn   = aws_iam_role.sfn.arn
  definition = data.template_file.sfn_definition.rendered
  tags       = module.sfn_naming.tags
}

data "template_file" "sfn_definition" {
  template = file("${var.sfn_path}/${var.sfn_name}/stepfunction.json")
  vars     = var.policy_variables
}
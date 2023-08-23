terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
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

# ------------------------------------------------------------------------------
# Defining resources names
# ------------------------------------------------------------------------------

module "irp_dev_deployment_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment", var.project_prefix])
}

#----------------------------------
# S3 Bucket names
#----------------------------------

module "s3b_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "datastorage"])
}

# ------------------------------------------------------------------------------
# Create Role for Dev Account for Deployments
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_dev_deploy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_number_devops}:root"]
    }
  }
}

# ------------------------------------------------------------------------------
# KMS, S3, SSM Policies
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "dev_deploy" {

  statement {
    effect = "Allow"
    actions = [
      "kms:TagResource",
      "kms:DeleteKey",
      "kms:ScheduleKeyDeletion",
      "kms:EnableKey",
      "kms:PutKeyPolicy",
      "kms:GenerateDataKey",
      "kms:EnableKeyRotation",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:DeleteAlias"
    ]
    resources = [
    "arn:aws:kms:${var.region}:${var.aws_account_number_env}:key/*"]
    sid = "kmspermissions"
  }

  statement {
    effect = "Allow"
    actions = ["kms:DeleteAlias"]
    resources = [
    "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/*"]
    sid = "kmsaliaspermissions"
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:CreateKey", "kms:CreateAlias", "kms:ListAliases"]
    resources = ["*"]
    sid       = "kmscreatepermissions"
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    sid       = "iampermissions"
  }

  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${module.s3b_data_naming.name}",
      "arn:aws:s3:::${module.s3b_data_naming.name}/*"
    ]
    sid = "s3permissions"
  }

  statement {
    actions = [
      "logs:DescribeLogGroups"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${var.region}:${var.aws_account_number_env}:log-group::log-stream:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:ListTagsForResource",
      "ssm:GetParameters",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource"
    ]
    resources = [
      "*"
    ]
  }
}

# ------------------------------------------------------------------------------
# Deployment role policy attachements
# ------------------------------------------------------------------------------

module "iro_dev_deployment_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.irp_dev_deployment_naming
  type        = "iro"
}

resource "aws_iam_role" "dev_deployment" {
  name               = module.iro_dev_deployment_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume_dev_deploy.json
  tags               = module.iro_dev_deployment_naming.tags
}

resource "aws_iam_policy" "dev_deployment" {
  name   = module.irp_dev_deployment_naming.name
  policy = data.aws_iam_policy_document.dev_deploy.json
}

resource "aws_iam_role_policy_attachment" "dev_deployment" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment.arn
}
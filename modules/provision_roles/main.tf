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

#----------------------------------
# KMS Key names
#----------------------------------

module "data_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "datakey"])
}

module "glue_enc_key_name" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "kma"
  purpose     = join("", [var.project_prefix, "-", "glueenckey"])
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

module "s3b_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "artifacts"])
}

module "s3b_glue_artifacts_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "s3b"
  purpose     = join("", [var.project_prefix, "-", "glueartifacts"])
}

#----------------------------------
# Glue names
#----------------------------------

module "glue_db_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "gluedb"])
}

module "glue_connection_sg_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sgp"
  purpose     = join("", [var.project_prefix, "-", "ingestjobconnectionsg"])
}

module "glue_ingest_job_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "ingestjobrole"])
}

module "glue_ingest_job_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glj"
  purpose     = join("", [var.project_prefix, "-", "ingestjob"])
}

#----------------------------------
# Lambda names
#----------------------------------

module "lambda_config_loader_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "lambdaconfigloader"])
}

module "lambda_config_loader_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "lambdaconfigloader"])
}

#----------------------------------
# Sfn names
#----------------------------------

module "sfn_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "etlsfn"])
}

module "etl_sfn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "stm"
  purpose     = join("", [var.project_prefix, "-", "etlsfn"])
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
    effect  = "Allow"
    actions = ["kms:DeleteAlias"]
    resources = [
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/${module.data_key_name.name}",
    "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/${module.glue_enc_key_name.name}"]
    sid = "kmsaliaspermissions"
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:CreateKey", "kms:CreateAlias", "kms:ListAliases"]
    resources = ["*"]
    sid       = "kmscreatepermissions"
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
      "iam:CreateRole",
      "iam:TagRole",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:DeleteRole",
      "iam:DeletePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.glue_ingest_job_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.lambda_config_loader_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.sfn_role_naming.name}"
    ]
    sid = "iam"
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    sid       = "iampermissions"
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeSubnets", "ec2:DescribeVpcs", "ec2:DescribeSecurityGroups"]
    resources = ["*"]
    sid       = "ec2describe"
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteSecurityGroup",
      "ec2:CreateSecurityGroup",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${var.aws_account_number_env}:security-group/${module.glue_connection_sg_naming.name}"
    ]
    sid = "ec2sgcreate"
  }

  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${module.s3b_data_naming.name}",
      "arn:aws:s3:::${module.s3b_data_naming.name}/*",
      "arn:aws:s3:::${module.s3b_artifacts_naming.name}",
      "arn:aws:s3:::${module.s3b_artifacts_naming.name}/*",
      "arn:aws:s3:::${module.s3b_glue_artifacts_naming.name}",
      "arn:aws:s3:::${module.s3b_glue_artifacts_naming.name}/*"
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
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift/*",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift"
    ]
  }
}

# ------------------------------------------------------------------------------
# ETL Policies
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "dev_deploy2" {
  statement {
    effect  = "Allow"
    actions = ["lambda:*"]
    resources = [
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_config_loader_naming.name}"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["states:*"]
    resources = [
      "arn:aws:states:${var.region}:${var.aws_account_number_env}:stateMachine:${module.etl_sfn_naming.name}"
    ]
  }

  statement {
    actions = [
      "glue:GetDatabase",
      "glue:UpdateDatabase",
      "glue:DeleteDatabase",
      "glue:CreateDatabase",
      "glue:GetDatabases",
      "glue:CreateConnection",
      "glue:DeleteConnection",
      "glue:GetConnection",
      "glue:UpdateConnection",
      "glue:GetTags"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:database/${module.glue_db_naming.name}",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:userDefinedFunction/${module.glue_db_naming.name}/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:table/${module.glue_db_naming.name}/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:catalog/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:catalog",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:connection/*",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:connection",
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:connection"
    ]
  }

  statement {
    actions = [
      "glue:GetSecurityConfiguration",
      "glue:CreateSecurityConfiguration",
      "glue:DeleteSecurityConfiguration"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "glue:DeleteJob",
      "glue:CreateJob",
      "glue:UpdateJob",
      "glue:GetJob",
      "glue:GetTags"
    ]
    effect    = "Allow"
    resources = ["arn:aws:glue:${var.region}:${var.aws_account_number_env}:job/${module.glue_ingest_job_naming.name}"]
  }
}

# ------------------------------------------------------------------------------
# Deployment role policy attachements
# ------------------------------------------------------------------------------

module "irp_dev_deployment_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment", var.project_prefix])
}

module "irp_dev_deployment_naming2" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment2", var.project_prefix])
}

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

resource "aws_iam_policy" "dev_deployment2" {
  name   = module.irp_dev_deployment_naming2.name
  policy = data.aws_iam_policy_document.dev_deploy2.json
}

resource "aws_iam_role_policy_attachment" "dev_deployment" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment2" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment2.arn
}

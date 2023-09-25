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

module "lambda_enrich_caar_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "lambdaenrichcaar"])
}

module "lambda_caar_enrich_agent_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "lambdacaarenrichagent"])
}

module "lambda_caar_enrich_office_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "lambdacaarenrichoffice"])
}

#----------------------------------
# Staging Glue Crawler names
#----------------------------------

module "crawler_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
}

module "staging_crawler_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "glr"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
}

#----------------------------------
# ECS Role & Policy
#----------------------------------

module "iro_ecs_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "taskrole"])
}

module "ipl_ecs_task_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "taskpolicy"])
}

module "ecr_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ecr"
  purpose     = join("", [var.project_prefix, "-", "alayapush"])
}

module "iro_ecs_task_execution_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayapushexecution"])
}

#----------------------------------
# Alaya Sync names
#----------------------------------

module "sqs_register_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sqs"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

module "sqs_register_dlq_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sqs"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregisterdlq"])
}

# lambdas - register
module "ipl_lambda_register_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

module "iro_lambda_register_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

module "lambda_register_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

# lambdas - schedule
module "ipl_lambda_schedule_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncschedule"])
}

module "iro_lambda_schedule_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncschedule"])
}

module "lambda_schedule_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncschedule"])
}

# lambdas - processing
module "ipl_lambda_processing_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncprocessing"])
}

module "iro_lambda_processing_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncprocessing"])
}

module "lambda_processing_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncprocessing"])
}

# lambdas - reduce
module "ipl_lambda_reduce_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncreduce"])
}

module "iro_lambda_reduce_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncreduce"])
}

module "lambda_reduce_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncreduce"])
}

# lambdas - execution
module "ipl_lambda_execution_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasyncexecution"])
}

module "iro_lambda_execution_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasyncexecution"])
}

module "lambda_execution_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", "alayasyncexecution"])
}

# dynamo table sync
module "dynamodb_sources_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "dyt"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

# sfn for sync
module "iro_sfn_alayasync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

module "ipl_sfn_alayasync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

module "sfm_alayasync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "stm"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
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

module "trigger_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "crontrigger"])
}

module "cron_trigger_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwr"
  purpose     = join("", [var.project_prefix, "-", "crontrigger"])
}

#----------------------------------
# Policy names
#----------------------------------

module "glue_ingest_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "glueingestpolicy"])
}

module "lambda_config_loader_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "lambdaconfigloaderpolicy"])
}

module "elt_sfn_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "etlsfnpolicy"])
}

module "cron_trigger_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "crontriggerpolicy"])
}

module "lambda_enrich_caar_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "lambdaenrichcaarpolicy"])
}

module "staging_glue_crawler_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "staginggluecrawlerpolicy"])
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
      "kms:DeleteAlias",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = [
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:key/*"
    ]
    sid = "kmspermissions"
  }

  statement {
    effect  = "Allow"
    actions = ["kms:DeleteAlias"]
    resources = [
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/${module.data_key_name.name}",
      "arn:aws:kms:${var.region}:${var.aws_account_number_env}:alias/${module.glue_enc_key_name.name}"
    ]
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
      "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.glue_ingest_job_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.lambda_config_loader_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.sfn_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.trigger_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.lambda_enrich_caar_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.crawler_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_ecs_task_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_ecs_task_execution_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_register_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_schedule_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_processing_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_reduce_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_lambda_execution_role_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:role/${module.iro_sfn_alayasync_naming.name}"
    ]
    sid = "iamroles"
  }

  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ecstask"
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:TagPolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion"

    ]
    resources = [
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.glue_ingest_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.lambda_config_loader_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.elt_sfn_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.cron_trigger_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.lambda_enrich_caar_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.staging_glue_crawler_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_ecs_task_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_register_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_schedule_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_processing_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_reduce_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_lambda_execution_policy_naming.name}",
      "arn:aws:iam::${var.aws_account_number_env}:policy/${module.ipl_sfn_alayasync_naming.name}"
    ]
    sid = "iampolicies"
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    sid       = "iampermissions"
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
    ]
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
      "ec2:RevokeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${var.aws_account_number_env}:security-group/*",
      "arn:aws:ec2:${var.region}:${var.aws_account_number_env}:vpc/*"
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
    actions = [
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
      "logs:ListTagsLogGroup",
      "logs:DeleteLogGroup",
      "logs:TagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${var.region}:${var.aws_account_number_env}:log-group:*:log-stream:*"
    ]
    sid = "cloudwatchlogcreation"
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift/*",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/*",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift",
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/${var.project_app_group}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DeleteParameter",
      "ssm:PutParameter",
      "ssm:ListTagsForResource",
      "ssm:AddTagsToResource"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:parameter/parameter/${var.site}/${var.environment}/${var.project_app_group}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_number_env}:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryCatalogData",
      "ecr:DeleteRepository",
      "ecr:TagResource",
      "ecr:ListTagsForResource",
      "ecr:PutImageTagMutability"
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${var.aws_account_number_env}:repository/${module.ecr_naming.name}"
    ]
    sid = "ecrrepocreation"
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
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_config_loader_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_caar_enrich_agent_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_caar_enrich_office_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:layer:delta_geopy:*",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:layer:delta_geopy",
      "arn:aws:lambda:${var.region}:336392948345:layer:AWSSDKPandas-Python310:*",
      "arn:aws:lambda:${var.region}:336392948345:layer:AWSSDKPandas-Python310",
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
    effect  = "Allow"
    actions = ["events:*"]
    resources = [
      "arn:aws:events:${var.region}:${var.aws_account_number_env}:rule/${module.cron_trigger_naming.name}"
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
      "glue:GetCrawler",
      "glue:DeleteCrawler",
      "glue:UpdateCrawler",
      "glue:CreateCrawler",
      "glue:GetTags"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:glue:${var.region}:${var.aws_account_number_env}:crawler/${module.staging_crawler_naming.name}"
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
# Alaya Sync
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "dev_deploy3" {
  statement {
    effect  = "Allow"
    actions = ["lambda:*"]
    resources = [
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_register_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_schedule_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_processing_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_reduce_naming.name}",
      "arn:aws:lambda:${var.region}:${var.aws_account_number_env}:function:${module.lambda_execution_naming.name}"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["states:*"]
    resources = [
      "arn:aws:states:${var.region}:${var.aws_account_number_env}:stateMachine:${module.sfm_alayasync_naming.name}"
    ]
    sid = "statessync"
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:DeleteEventSourceMapping",
      "lambda:UpdateEventSourceMapping",
      "lambda:CreateEventSourceMapping",
      "lambda:ListEventSourceMappings",
      "lambda:GetEventSourceMapping"
    ]
    resources = ["*"]
    sid = "sourcemappingsync"
  }

  statement {
    effect = "Allow"
    actions = [
      "sqs:createqueue",
      "sqs:getqueueattributes",
      "sqs:deletequeue",
      "sqs:tagqueue",
      "sqs:setqueueattributes"
    ]
    resources = [
      "arn:aws:sqs:${var.region}:${var.aws_account_number_env}:${module.sqs_register_data_naming.name}",
      "arn:aws:sqs:${var.region}:${var.aws_account_number_env}:${module.sqs_register_dlq_data_naming.name}"
    ]
    sid = "sqssync"
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:Delete*",
      "dynamodb:Describe*",
      "dynamodb:TagResource",
      "dynamodb:List*"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.aws_account_number_env}:table/${module.dynamodb_sources_naming.name}"
    ]
    sid = "dynamosync"
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

module "irp_dev_deployment_naming3" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  env         = var.environment
  purpose     = join("", ["deployment3", var.project_prefix])
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

resource "aws_iam_policy" "dev_deployment3" {
  name   = module.irp_dev_deployment_naming3.name
  policy = data.aws_iam_policy_document.dev_deploy3.json
}

resource "aws_iam_role_policy_attachment" "dev_deployment" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment2" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment2.arn
}

resource "aws_iam_role_policy_attachment" "dev_deployment3" {
  role       = aws_iam_role.dev_deployment.name
  policy_arn = aws_iam_policy.dev_deployment3.arn
}
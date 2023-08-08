terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_ssm_parameter" "s3_code_bucket_arn" {
  count = var.create_code_bucket ? 0 : 1
  name = "/${var.datapipeline_name}/s3/code_bucket_arn"
}

data "aws_ssm_parameter" "s3_code_bucket_name" {
  count = var.create_code_bucket ? 0 : 1
  name = "/${var.datapipeline_name}/s3/code_bucket"
}

data "aws_ssm_parameter" "iam_role_cbd_build_arn" {
  count = var.create_iam_roles ? 0 : 1
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_build_arn"
}

data "aws_ssm_parameter" "iam_role_cbd_provision_arn" {
  count = var.create_iam_roles ? 0 : 1
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_provision_arn"
}

data "aws_ssm_parameter" "iam_role_cpl_arn" {
  count = var.create_iam_roles ? 0 : 1
  name        = "/${var.datapipeline_name}/iam/iam_role_cpl_arn"
}

data "aws_ssm_parameter" "iam_role_cbd_build_name" {
  count = var.create_iam_roles ? 0 : 1
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_build_name"
}

data "aws_ssm_parameter" "iam_role_cbd_provision_name" {
  count = var.create_iam_roles ? 0 : 1
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_provision_name"
}

data "aws_ssm_parameter" "iam_role_cpl_name" {
  count = var.create_iam_roles ? 0 : 1
  name        = "/${var.datapipeline_name}/iam/iam_role_cpl_name"
}


module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

module "s3_bucket" {
  count = var.create_code_bucket ? 1 : 0
  source = "./modules/s3"
  datapipeline_name = var.datapipeline_name
  environment_devops = var.environment_devops
  project_app_group = var.project_app_group
  project_ledger = var.project_ledger
  project_prefix = var.project_prefix
  site = var.site
  tier = var.tier
  zone = var.zone 
}

module "iam_roles" {
  count = var.create_iam_roles ? 1 : 0
  source = "./modules/iam"
  aws_account_number_devops = var.aws_account_number_devops
  codestar_github_connection = var.codestar_github_connection
  datapipeline_name = var.datapipeline_name
  environment_devops = var.environment_devops
  project_app_group = var.project_app_group
  project_ledger = var.project_ledger
  project_prefix = var.project_prefix
  site = var.site
  s3_code_bucket_arn = var.create_code_bucket ? module.s3_bucket[0].s3_code_bucket_arn : data.aws_ssm_parameter.s3_code_bucket_arn[0].value
  tier = var.tier
  zone = var.zone 
}

module "codepipeline" {
    source = "./modules/codepipeline"

    aws_account_number_devops = var.aws_account_number_devops
    chatbot_arn_codepipeline_notification = var.chatbot_arn_codepipeline_notification
    codestar_github_connection = var.codestar_github_connection
    
    code_source_branch = var.code_source_branch
    compute_type = var.compute_type
    datapipeline_name = var.datapipeline_name
    dev_deployment_role = var.dev_deployment_role
    enable_codepipeline_notification = var.enable_codepipeline_notification
    environment_dev = var.environment_dev
    environment_devops = var.environment_devops
    environment_variable_codebuild = var.environment_variable_codebuild
    environment_variable_codeprovision = var.environment_variable_codeprovision
    iam_role_cbd_build_arn = var.create_iam_roles ? module.iam_roles[0].iam_role_cbd_build_arn : data.aws_ssm_parameter.iam_role_cbd_build_arn[0].value
    iam_role_cbd_provision_arn = var.create_iam_roles ? module.iam_roles[0].iam_role_cbd_provision_arn : data.aws_ssm_parameter.iam_role_cbd_provision_arn[0].value
    iam_role_cpl_arn = var.create_iam_roles ? module.iam_roles[0].iam_role_cpl_arn : data.aws_ssm_parameter.iam_role_cpl_arn[0].value
    image = var.image
    image_pull_credentials_type = var.image_pull_credentials_type
    privileged_mode = var.privileged_mode
    project_app_group = var.project_app_group
    project_ledger = var.project_ledger
    project_prefix = var.project_prefix
    s3_code_bucket_name = var.create_code_bucket ? module.s3_bucket[0].s3_code_bucket_name : data.aws_ssm_parameter.s3_code_bucket_name[0].value
    site = var.site
    sns_arn_codepipeline_notification = var.sns_arn_codepipeline_notification
    source_owner = var.source_owner
    source_repo = var.source_repo
    tier = var.tier
    timeout_for_build = var.timeout_for_build
    timeout_for_provision = var.timeout_for_provision
    type = var.type
    zone = var.zone

}

module "post_creation_privileges" {
    source = "./modules/post_creation_privileges"

    aws_account_number_devops = var.aws_account_number_devops
    codepipeline_cbd_build_naming = module.codepipeline.cbd_build_naming
    codepipeline_codebuild_project_build_arn = module.codepipeline.codebuild_project_build_arn
    codepipeline_codebuild_project_provision_arn = module.codepipeline.codebuild_project_provision_arn
    datapipeline_name = var.datapipeline_name
    dev_deployment_role = var.dev_deployment_role
    environment_dev = var.environment_dev
    environment_devops = var.environment_devops
    iam_role_cbd_build_name = var.create_iam_roles ? module.iam_roles[0].iam_role_cbd_build_name : data.aws_ssm_parameter.iam_role_cbd_build_name[0].value
    iam_role_cbd_provision_name = var.create_iam_roles ? module.iam_roles[0].iam_role_cbd_provision_name : data.aws_ssm_parameter.iam_role_cbd_provision_name[0].value
    iam_role_cpl_name = var.create_iam_roles ? module.iam_roles[0].iam_role_cpl_name : data.aws_ssm_parameter.iam_role_cpl_name[0].value
    project_app_group = var.project_app_group
    project_ledger = var.project_ledger
    project_prefix = var.project_prefix
    region = var.region[var.site]
    site = var.site
    tier = var.tier
    zone = var.zone
}

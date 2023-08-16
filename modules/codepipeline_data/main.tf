terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


module "s3_bucket" {
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
  source = "./modules/iam"
  aws_account_number_devops = var.aws_account_number_devops
  codestar_github_connection = var.codestar_github_connection
  datapipeline_name = var.datapipeline_name
  environment_devops = var.environment_devops
  project_app_group = var.project_app_group
  project_ledger = var.project_ledger
  project_prefix = var.project_prefix
  site = var.site
  sns_arn_codepipeline_notification = var.sns_arn_codepipeline_notification
  s3_code_bucket_arn = module.s3_bucket.s3_code_bucket_arn
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
    iam_role_cbd_build_arn = module.iam_roles.iam_role_cbd_build_arn
    iam_role_cbd_provision_arn = module.iam_roles.iam_role_cbd_provision_arn
    iam_role_cpl_arn = module.iam_roles.iam_role_cpl_arn
    image = var.image
    image_pull_credentials_type = var.image_pull_credentials_type
    privileged_mode = var.privileged_mode
    project_app_group = var.project_app_group
    project_ledger = var.project_ledger
    project_prefix = var.project_prefix
    s3_code_bucket_name = module.s3_bucket.s3_code_bucket_name
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
    iam_role_cbd_build_name = module.iam_roles.iam_role_cbd_build_name
    iam_role_cbd_provision_name = module.iam_roles.iam_role_cbd_provision_name
    iam_role_cpl_name = module.iam_roles.iam_role_cpl_name
    project_app_group = var.project_app_group
    project_ledger = var.project_ledger
    project_prefix = var.project_prefix
    region = var.region[var.site]
    site = var.site
    tier = var.tier
    zone = var.zone
}
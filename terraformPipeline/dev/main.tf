provider "aws" {
  region  = var.region[var.site]
  profile = var.aws_profile_code
}

provider "aws" {
  alias   = "code"
  region  = var.region[var.site]
  profile = var.aws_profile_code
}

provider "aws" {
  alias   = "dev"
  region  = var.region[var.site]
  profile = var.aws_profile_dev
}

module "provision_roles" {
  source = "../../modules/provision_roles"

  providers = {
    aws = aws.dev
  }

  aws_account_number_devops = var.aws_account_number_devops
  aws_account_number_env    = var.aws_account_number_env
  environment               = var.environment_dev
  environment_devops        = var.environment_devops
  project_app_group         = var.project_app_group
  project_ledger            = var.project_ledger
  project_prefix            = var.project_prefix
  region                    = var.region[var.site]
  site                      = var.site
  tier                      = var.tier
  zone                      = var.zone
}

module "codepipeline" {
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//codepipeline_data?ref=v0.0.7"

  providers = {
    aws = aws.code
  }

  aws_account_number_devops             = var.aws_account_number_devops
  chatbot_arn_codepipeline_notification = var.chatbot_arn_codepipeline_notification
  code_source_branch                    = var.code_source_branch
  codestar_github_connection            = var.codestar_github_connection
  compute_type                          = var.compute_type
  create_s3_bucket                      = var.create_s3_bucket
  datapipeline_name                     = var.datapipeline_name
  dev_deployment_role                   = module.provision_roles.provision_role_arn
  enable_codepipeline_notification      = var.enable_codepipeline_notification
  environment_dev                       = var.environment_dev
  environment_devops                    = var.environment_devops

  environment_variable_codebuild = [
    {
      name  = "SITE"
      value = var.site
    },
    {
      name  = "ENVIRONMENT_DEVOPS"
      value = var.environment_devops
    },
    {
      name  = "JFROG_REPOSITORY_NAME"
      value = var.jfrog_repository_name
    }
  ]

  environment_variable_codeprovision = [
    {
      name  = "SITE"
      value = var.site
    },
    {
      name  = "ENV_ACCOUNT_NUMBER"
      value = var.aws_account_number_env
    },
    {
      name  = "ENVIRONMENT"
      value = var.environment_dev
    },
    {
      name  = "ENVIRONMENT_DEVOPS"
      value = var.environment_devops
    }
  ]

  image                             = var.image
  image_build                       = var.image_build
  image_pull_credentials_type       = var.image_pull_credentials_type
  project_app_group                 = var.project_app_group
  project_ledger                    = var.project_ledger
  project_prefix                    = var.project_prefix
  privileged_mode_build             = true 
  s3_bucket_name                    = var.s3_bucket_name
  site                              = var.site
  sns_arn_codepipeline_notification = var.sns_arn_codepipeline_notification
  source_owner                      = var.source_owner
  source_repo                       = var.source_repo
  tier                              = var.tier
  timeout_for_build                 = var.timeout_for_build
  timeout_for_provision             = var.timeout_for_provision
  type                              = var.type
  zone                              = var.zone

}
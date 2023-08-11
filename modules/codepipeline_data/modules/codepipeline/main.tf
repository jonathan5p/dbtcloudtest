data "aws_region" "current" {}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

# ------------------------------------------------------------------------------
# Create Codepipeline
# ------------------------------------------------------------------------------
module "cpl_project_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cpl"
  purpose     =  join("", [var.project_prefix, var.environment_dev])
}

resource "aws_codepipeline" "codepipeline" {
  name     = module.cpl_project_naming.name
  role_arn = var.iam_role_cpl_arn
  tags     = module.cpl_project_naming.tags
  artifact_store {
    location = var.s3_code_bucket_name
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["sourceOutput"]
      run_order        = "1"
      configuration = {
        ConnectionArn        = var.codestar_github_connection
        FullRepositoryId     = "${var.source_owner}/${var.source_repo}"
        BranchName           = var.code_source_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["sourceOutput"]
      output_artifacts = ["buildOutput"]
      namespace        = "BuildVariables"
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }
  stage {
    name = "TerraformPlan"
    action {
      name            = "Provision"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["sourceOutput"]
      version         = "1"
      configuration = {
        ProjectName          = aws_codebuild_project.provision.name
        EnvironmentVariables = var.privileged_mode == false ? "[{\"name\":\"TF_ACTION\",\"value\":\"plan\"}]" : "[{\"name\":\"TF_ACTION\",\"value\":\"deploy\"},{\"name\":\"IMAGE_URI\",\"value\":\"#{BuildVariables.IMAGE_URI}\"}]"
      }
    }
  }
  stage {
    name = "Approve"
    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        NotificationArn = "${var.sns_arn_codepipeline_notification}"
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Provision"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["sourceOutput"]
      version         = "1"
      configuration = {
        ProjectName          = aws_codebuild_project.provision.name
        EnvironmentVariables = var.privileged_mode == false ? "[{\"name\":\"TF_ACTION\",\"value\":\"deploy\"}]" : "[{\"name\":\"TF_ACTION\",\"value\":\"deploy\"},{\"name\":\"IMAGE_URI\",\"value\":\"#{BuildVariables.IMAGE_URI}\"}]"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Create Codebuild
# ------------------------------------------------------------------------------
module "cbd_build_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cbd"
  purpose     = join("", ["build", var.project_prefix, var.environment_dev])

}

resource "aws_codebuild_project" "build" {
  name          = module.cbd_build_naming.name
  description   = module.cbd_build_naming.name
  build_timeout = var.timeout_for_build
  service_role  = var.iam_role_cbd_build_arn
  tags          = module.cbd_build_naming.tags
  artifacts {
    type = "CODEPIPELINE"
  }
  cache {
    type     = "S3"
    location = var.s3_code_bucket_name
  }
  environment {
    compute_type                = var.compute_type
    image                       = var.image
    type                        = var.type
    image_pull_credentials_type = var.image_pull_credentials_type
    privileged_mode             = var.privileged_mode
    environment_variable {
      name  = "GITHUB_BRANCH"
      value = var.code_source_branch
    }
    dynamic "environment_variable" {
      for_each = [for i in var.environment_variable_codebuild : {
        name  = i.name
        value = i.value
      }]
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
      }
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/build/${module.cbd_build_naming.name}"
      stream_name = module.cbd_build_naming.name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/buildspec.yml"
  }
}

# ------------------------------------------------------------------------------
# Create Provisioning
# ------------------------------------------------------------------------------
module "cbd_provision_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cbd"
  purpose     = join("", ["provision", var.project_prefix, var.environment_dev])
}

resource "aws_codebuild_project" "provision" {
  name          = module.cbd_provision_naming.name
  description   = module.cbd_provision_naming.name
  build_timeout = var.timeout_for_provision
  service_role  = var.iam_role_cbd_provision_arn
  tags          = module.cbd_provision_naming.tags
  artifacts {
    type = "CODEPIPELINE"
  }
  cache {
    type     = "S3"
    location = var.s3_code_bucket_name
  }
  environment {
    compute_type                = var.compute_type
    image                       = var.image
    type                        = var.type
    image_pull_credentials_type = var.image_pull_credentials_type
    environment_variable {
      name  = "S3_FOR_TERRAFORM_STATE"
      value = join("", ["s3://", var.s3_code_bucket_name, "/" ,var.environment_dev, "/terraform_state"])
    }
    environment_variable {
      name  = "S3_FOR_TERRAFORM_PLAN"
      value = join("", ["s3://", var.s3_code_bucket_name, "/" ,var.environment_dev, "/terraform_plan"])
    }
    environment_variable {
      name  = "TERRAFORM_DEPLOYMENT_ROLE"
      value = var.dev_deployment_role
    }
    environment_variable {
      name  = "TERRAFORM_WORKSPACE"
      value = var.environment_dev
    }
    environment_variable {
      name  = "S3_FOR_TERRAFORM_LOCK"
      value = join("", ["s3://", var.s3_code_bucket_name, "/terraform_state/terraform.tfstate.d/", var.environment_dev, "/"])
    }
    environment_variable {
      name  = "SOURCE_BRANCH"
      value = var.code_source_branch
    }

    dynamic "environment_variable" {
      for_each = [for i in var.environment_variable_codeprovision : {
        name  = i.name
        value = i.value
      }]
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
      }
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/provisioning/${module.cbd_provision_naming.name}"
      stream_name = module.cbd_provision_naming.name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/buildspecTerraform.yml"
  }
}

resource "aws_codestarnotifications_notification_rule" "notification" {
  count       = var.enable_codepipeline_notification ? 1 : 0
  detail_type = "BASIC"
  event_type_ids = [
    "codepipeline-pipeline-stage-execution-failed",
    "codepipeline-pipeline-stage-execution-canceled",
    "codepipeline-pipeline-pipeline-execution-canceled",
    "codepipeline-pipeline-pipeline-execution-succeeded"
  ]
  name     = "${module.cpl_project_naming.name}-notification-${var.environment_dev}"
  resource = aws_codepipeline.codepipeline.arn
  #target {
  #  address = var.sns_arn_codepipeline_notification
  #  type    = "SNS"
  #}
  target {
    address = var.chatbot_arn_codepipeline_notification
    type    = "AWSChatbotSlack"
  }
}


resource "aws_ssm_parameter" "active_environment" {
  name        = "/${var.datapipeline_name}/${var.code_source_branch}/active_environment"
  type        = "SecureString"
  value       = "region,${data.aws_region.current.name};dynamo_state_backend,${var.dynamo_state_backend};bucket_backend,${var.s3_code_bucket_name};TF_VAR_role_arn,${var.dev_deployment_role};TF_VAR_environment,${var.environment_dev};TF_VAR_site,${var.site}"
  description = "Name for the code bucket datapipeline"
  overwrite   = true
}

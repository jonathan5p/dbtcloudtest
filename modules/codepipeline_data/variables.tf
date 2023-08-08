variable "aws_account_number_devops" {
  default = {}
}

variable "chatbot_arn_codepipeline_notification" {
  default = {}
}

variable "code_source_branch" {
  default = {}
}

variable "codestar_github_connection" {
}

variable "compute_type" {
  default = {}
}

variable "datapipeline_name" {
 type = string
}

variable "dev_deployment_role" {
  default = {}
}

variable "enable_codepipeline_notification" {
  default = {}
}

variable "environment" {
  default = {}
}

variable "environment_dev" {
  default = {}
}

variable "environment_devops" {
  default = {}
}

variable "environment_variable" {
  type = list(object(
    {
      name  = string
      value = string
  }))
  default = []
}

variable "environment_variable_codebuild" {
  type = list(object(
    {
      name  = string
      value = string
  }))
  default = []
}

variable "environment_variable_codeprovision" {
  type = list(object(
    {
      name  = string
      value = string
  }))
  default = []
}

variable "image" {
  default = {}
}

variable "image_pull_credentials_type" {
  default = {}
}

variable "privileged_mode" {
  description = "Enables running the Docker daemon inside a Docker container. Set to true only if the build project is used to build Docker images."
  default     = false
}

variable "project_app_group" {
  default = {}
}

variable "project_ledger" {
  default = {}
}

variable "project_prefix" {
  default = {}
}

variable "region" {
  description = "Region in which resources to be created"
  default = {
    "aue1" = "us-east-1"
    "aue2" = "us-east-2"
    "auw1" = "us-west-1"
    "auw2" = "us-west-2"
  }
}

variable "site" {
  default = {}
}

variable "sns_arn_codepipeline_notification" {
  default = {}
}

variable "source_owner" {
  default = {}
}

variable "source_repo" {
  default = {}
}

variable "tier" {
  default = {}
}

variable "timeout_for_build" {
  default = {}
}

variable "timeout_for_provision" {
  default = {}
}

variable "type" {
  default = {}
}

variable "zone" {
  default = {}
}



variable "create_code_bucket" {
    default = true
    type    = bool
}

variable "s3_code_bucket_arn" {
    default = ""
    type    = string
}

variable "s3_code_bucket" {
    default = ""
    type = string
}

variable "create_iam_roles" {
    default = true
    type    = bool
}

variable "iam_role_cbd_build_arn" {
    default = ""
}

variable "iam_role_cbd_build_name" {
    default = ""
}

variable "iam_role_cbd_provision_arn" {
    default = ""
}

variable "iam_role_cbd_provision_name" {
    default = ""
}

variable "iam_role_cpl_arn" {
    default = ""
}

variable "iam_role_cpl_name" {
    default = ""
}
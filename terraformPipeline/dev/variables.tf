variable "aws_account_number_devops" {
  description = "Devops AWS Account Number"
  default     = "522857095635"
}

variable "aws_account_number_env" {
  description = "Dev Env  AWS Account Number"
  default     = "497607366324"
}

variable "aws_profile_code" {
  description = "AWS profile for Devops Account"
}

variable "aws_profile_dev" {
  description = "AWS profile for Dev Account"
}

variable "chatbot_arn_codepipeline_notification" {
  description = "Chatbot ARN to be used by codepipeline for notification"
  default     = "arn:aws:chatbot::00000000000:chat-configuration/slack-channel/channel-name"
}

variable "code_source_branch" {
  description = "Github Repo branch from where code will be executed for build and deploy"
  default     = {}
}

variable "codestar_github_connection" {
  default = "arn:aws:codestar-connections:us-east-1:522857095635:connection/27115013-e5c8-40ab-a75d-06ac874306b2"
}

variable "compute_type" {
  description = "codebuild compute capacity"
  default     = "BUILD_GENERAL1_MEDIUM"
}

variable "datapipeline_name" {
  description = "Name of the pipeline to be deployied"
  default     = "datapipeline_cicd_oidh"
}

variable "enable_codepipeline_notification" {
  description = "to enable codepipeline notification set to true, else set to false"
  default     = false
  type        = bool
}

variable "environment_dev" {
  description = "Env value belongs to Dev account like d1"
  default     = {}
}

variable "environment_devops" {
  description = "Env value belongs to Devops account like c1"
  default     = {}
}

variable "image" {
  description = "codebuild image to be used"
  default     = "aws/codebuild/standard:5.0"
}

variable "image_pull_credentials_type" {
  default = "CODEBUILD"
}

variable "jfrog_repository_name" {
  default = ""
}

variable "project_app_group" {
  description = "This is Bright's specified value"
  default     = "ds"
}

variable "project_ledger" {
  description = "This is Bright's specified value"
  default     = ""
}

variable "project_prefix" {
  description = "This is part of bright naming convention belongs to project repo and resources purpose"
  default     = "oidh"
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
  description = "Site is a part of Bright Naming convention aue1 for us-east-1"
  default     = {}
}

variable "sns_arn_codepipeline_notification" {
  description = "SNS ARN to be used by codepipeline for notification"
  default     = "arn:aws:sns:us-east-1:522857095635:aue1c1z1snrbcompipelinenotification"
}

variable "source_owner" {
  description = "Repo Owner, most likely BrightMLS in all cases"
  default     = "BrightMLS"
}

variable "source_repo" {
  description = "Repo name"
  default     = "bdmp-oidh"
}

variable "tier" {
  description = "This is Bright's specified value"
  default     = "oidh"
}

variable "timeout_for_build" {
  description = "Codebuild for build stage timeout"
  default     = "120"
}

variable "timeout_for_provision" {
  description = "Codebuild for build stage timeout"
  default     = "60"
}

variable "type" {
  default = "LINUX_CONTAINER"
}

variable "zone" {
  description = "This is Bright's specified value"
  default     = ""
}
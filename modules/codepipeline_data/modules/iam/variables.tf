variable "aws_account_number_devops" {
  default = {}
}

variable "codestar_github_connection" {
}

variable "datapipeline_name" {
    type = string
}

variable "environment_devops" {
  default = {}
}

variable "iam_role_cpl_arn" {
  default = ""
  type    = string
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

variable "site" {
  default = {}
}

variable "s3_code_bucket_arn" {
  default = {}
}

variable "tier" {
  default = {}
}

variable "zone" {
  default = {}
}
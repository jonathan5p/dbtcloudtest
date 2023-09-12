variable "aws_account_number_devops" {
  default = {}
}

variable "aws_account_number_env" {
  default = {}
}

variable "ecs_execution_role" {
  description = "Linked role for ECS"
  default = "ecsTaskExecutionRole"
}

variable "environment" {
  default = {}
}

variable "environment_devops" {
  default = {}
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
  default = {}
}

variable "site" {
  default = {}
}

variable "tier" {
  default = {}
}

variable "zone" {
  default = {}
}
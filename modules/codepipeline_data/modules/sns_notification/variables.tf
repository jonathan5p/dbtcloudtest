variable "datapipeline_name" {
    type = string
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

variable "site" {
  default = {}
}

variable "sns_notification_create_approval" {
    type = bool
}

variable "tier" {
  default = {}
}

variable "zone" {
  default = {}
}
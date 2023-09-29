variable "base_naming" {
  default = null
}

variable "cron_trigger_enabled" {
  description = "Boolean variable to activate/deactivate the etl cron trigger"
  default     = false
}

variable "cron_schedule" {
  description = "Cron expresion applied to the EvenBridge scheduled rule"
  default     = "cron(0 23 * * ? *)"
}

variable "environment" {
  description = "Env value belongs to dev, tst, prod account like d1, t1, p1 resp."
  default     = {}
}

variable "environment_devops" {
  description = "Env value belongs to dev, tst, prod account like d1, t1, p1 resp."
  default     = {}
}

variable "project_app_group" {
  description = "This is Bright's specified value"
  default     = {}
}

variable "project_ledger" {
  description = "This is Bright's specified value"
  default     = {}
}

variable "policy_variables" {
  type        = map(string)
  description = "References to the project resources (e.g. KMS keys, S3 Buckets, etc.)"
  default     = {}
}

variable "project_prefix" {
  description = "This is part of bright naming convention belongs to project repo and resources purpose"
  default     = {}
}

variable "site" {
  description = "Site is a part of Bright Naming convention aue1 for us-east-1"
  default     = {}
}

variable "tier" {
  description = "This is Bright's specified value"
  default     = {}
}

variable "zone" {
  default = {}
}
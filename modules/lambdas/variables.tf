variable "environment" {
  description = "Env value belongs to dev, tst, prod account like d1, t1, p1 resp."
  default     = {}
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables for the executor"
  default = {
    "source_code" : "lambda github"
  }
}

variable "lambda_name" {
  default = {}
}

variable "lambda_path" {
  default = {}
}

variable "policy_variables" {
  type        = map(string)
  description = "Policy variables for executor policy"
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
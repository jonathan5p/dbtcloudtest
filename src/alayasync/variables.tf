variable "alaya_trigger_key" {
  description = "S3 key of the file that will trigger the update to alaya process"
}

variable "environment" {
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

variable "project_objects" {
    type = map(string)
    description = "Policy variables for executor policy"
    default = {}
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
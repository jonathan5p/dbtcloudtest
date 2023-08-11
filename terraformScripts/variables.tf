variable "role_arn" {
  description = "This is used by terraform scripts to deploy resources"
  default     = {}
}

variable "environment" {
  description = "Env value belongs to dev, tst, prod account like d1, t1, p1 resp."
  default     = {}
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

variable "zone" {
  description = "This is Bright's specified value"
  default     = "z1"
}

variable "project_prefix" {
  description = "This is part of bright naming convention belongs to project repo and resources purpose"
  default     = "oidh"
}

variable "dynamo_state_backend" {
  default = "terraform-state-lock-dynamo"
}
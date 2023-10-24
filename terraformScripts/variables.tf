# Project parameters
variable "environment_devops" {
  default = {}
}

variable "environment" {
  description = "Env value belongs to dev, tst, prod account like d1, t1, p1 resp."
  default     = {}
}

variable "project_app_group" {
  description = "This is Bright's specified value"
  default     = "oidh"
}

variable "project_ledger" {
  description = "This is Bright's specified value"
  default     = "oidh"
}

variable "project_prefix" {
  description = "This is part of bright naming convention belongs to project repo and resources purpose"
  default     = "oidhbrtest"
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

variable "role_arn" {
  description = "Role used in the target account to deploy resources"
}

variable "site" {
  description = "Site is a part of Bright Naming convention aue1 for us-east-1"
  default     = {}
}

variable "tier" {
  description = "This is Bright's specified value"
  default     = "oidh"
}

variable "zone" {
  default = {}
}

# Data KMS Admins and Users
variable "kms_data_admins" {
  description = "Arn of the IAM roles/users that will administrate the kms data key"
  default     = []
}

variable "kms_data_users" {
  description = "Arn of the IAM roles/users that will use the kms data key"
  default     = []
}

# Glue KMS Admins and Users
variable "kms_glue_admins" {
  description = "Arn of the IAM roles/users that will administrate the kms data key"
  default     = []
}

variable "kms_glue_users" {
  description = "Arn of the IAM roles/users that will use the kms data key"
  default     = []
}

# S3 parameters
variable "s3_bucket_tmp_expiration_days" {
  description = "Expiration lifecycle policy for all objects store in the tmp prefix of the s3 buckets"
}

variable "s3_bucket_objects_expiration_days" {
  description = "Expiration lifecycle policy for all objects store in the s3 buckets except tmp"
}

variable "s3_bucket_objects_transition_days" {
  description = "Transition to Inteligent Tiering lifecycle policy for all objects store in the s3 buckets except tmp"
}

# Glue max records per file
variable "glue_max_records_per_file" {
  description = "Maximum number of records per parquet file write in the deduplication jobs"
  default     = 5000
}

# Update alaya triggers
variable "payload_trigger_key" {
  description = "S3 key of the prefix where the gethubid process will save and load its execution files"
  default     = "gethubid"
}

# ECS parameters
variable "ecs_task_alaya_cpu" {
  description = "CPU for ecs task post to Alaya"
  default     = 2048
}

variable "ecs_task_alaya_memory" {
  description = "Memory for ecs task post to Alaya"
  default     = 4096
}

variable "retention_days_ecs_alaya_logs" {
  description = "Retention days for logs in cloudwatch"
  default     = 30
}

variable "ecs_subnets" {
  type        = string
  description = "comma separated values for the subnets to use"
}

variable "concurrent_tasks" {
  type        = number
  description = "number of concurrent tasks for alaya sync"
  default     = 18
}
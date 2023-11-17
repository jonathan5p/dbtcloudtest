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

# Glue geosvc subnet id
variable "glue_geosvc_subnetid" {
  description = "Subnet id used to create the glue connection to acces the GeoSvc API endpoint"
  type        = string
}

# Update alaya triggers
variable "alaya_trigger_key" {
  description = "S3 key of the file that will trigger the update to alaya process"
  default     = "consume_data/resultData/executions_1"
}

# Event bridge cron trigger
variable "cron_trigger_enabled" {
  description = "Boolean variable to activate/deactivate the etl cron trigger"
  default     = false
}

variable "cron_schedule" {
  description = "Cron expresion applied to the EvenBridge scheduled rule"
  default     = "cron(0 23 * * ? *)"
}

# ECS parameters
variable "ecs_task_alaya_cpu" {
  description = "CPU for ecs task post to Alaya"
  default     = 1024
}

variable "ecs_task_alaya_memory" {
  description = "Memory for ecs task post to Alaya"
  default     = 2048
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
  default     = 25
}

variable "ttl_days_async" {
  type        = number
  description = "number of days to keep lambda execution when running alaya sync"
  default     = 2
}

variable "lambda_task_alaya_memory" {
  type        = number
  default     = 512
}
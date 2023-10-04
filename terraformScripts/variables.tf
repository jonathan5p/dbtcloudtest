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

# Lambda enrich caar data parameters
variable "lambda_ec_agent_source_table_name" {
  description = "Name of the agent table registered in the S3 Raw layer"
  default     = "bright_raw_agent_latest"
}

variable "lambda_ec_agent_target_table_name" {
  description = "Name of the agent table registered in the S3 Staging layer"
  default     = "bright_staging_agent_latest"
}

variable "lambda_ec_office_source_table_name" {
  description = "Name of the office table registered in the S3 Raw layer"
  default     = "bright_raw_office_latest"
}

variable "lambda_ec_office_target_table_name" {
  description = "Name of the office table registered in the S3 Staging layer"
  default     = "bright_staging_office_latest"
}

# Glue max records per file
variable "glue_max_records_per_file" {
  description = "NMaximum number of records per parquet file write in the deduplication jobs"
  default     = 1000
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

# Aurora serverlessv2 postgresql db
variable "aurora_backup_retention_period" {
  description = "Admin tool aurora postgresql database retention period"
  default     = 30
}

variable "aurora_preferred_backup_window" {
  description = "Admin tool aurora postgresql database preferred backup window"
  default     = "21:00-00:00"
}

variable "aurora_max_capacity" {
  description = "Admin tool aurora postgresql max capacity"
  default     = 4
}

variable "aurora_min_capacity" {
  description = "Admin tool aurora postgresql min capacity"
  default     = 2
}
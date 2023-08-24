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

variable "lambda_reserved_concurrent_executions" {
  description = "Lambda reserved concurrency for all functions deployed"
  default     = null
}

# Lambda parameters
variable "lambda_timeout" {
  description = "Lambda timeout for all functions deployed"
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda memory size for all functions deployed"
  default     = 256
}

variable "lambda_retry_max_attempts" {
  description = "Lambda retry attempts for all functions deployed in the step function"
  default     = 0
}

variable "lambda_retry_interval" {
  description = "Lambda retry interval for all functions deployed in the step function"
  default     = 2
}

variable "lambda_retry_backoff_rate" {
  description = "Lambda backoff rate for all functions deployed in the step function"
  default     = 2
}

# Glue parameters
variable "glue_max_concurrent_runs" {
  description = "Glue maximum concurrent running jobs for all jobs deployed"
  default     = 4
}

variable "glue_timeout" {
  description = "Glue timeout for all jobs deployed"
  default     = 60
}

variable "glue_worker_type" {
  description = "Glue wokertype for all jobs deployed"
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Glue maximum number of workers"
  default     = 4
}

variable "glue_retry_max_attempts" {
  description = "Glue retry attempts for all jobs deployed"
  default     = 0
}

variable "glue_retry_interval" {
  description = "Glue retry interval for all jobs deployed"
  default     = 2
}
variable "glue_retry_backoff_rate" {
  description = "Glue backoff rate for all jobs deployed"
  default     = 2
}

variable "glue_redshift_conn_subnet_id" {
  description = "Subnet id used to access the Redshift cluster"
  default     = ""
}

# Event bridge cron trigger
variable "cron_schedule" {
  description = "Cron expresion applied to the EvenBridge scheduled rule"
  default     = "cron(0 23 * * ? *)"
}
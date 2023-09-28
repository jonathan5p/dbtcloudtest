variable "base_naming" {
  default = null
}

variable "project_prefix" {
  default = ""
}

# Glue parameters
variable "max_concurrent_runs" {
  description = "Glue maximum concurrent running jobs for all jobs deployed"
  default     = 4
}

variable "timeout" {
  description = "Glue timeout for all jobs deployed"
  default     = 60
}

variable "worker_type" {
  description = "Glue wokertype for all jobs deployed"
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Glue maximum number of workers"
  default     = 4
}

variable "retry_max_attempts" {
  description = "Glue retry attempts for all jobs deployed"
  default     = 0
}

variable "retry_interval" {
  description = "Glue retry interval for all jobs deployed"
  default     = 2
}

variable "retry_backoff_rate" {
  description = "Glue backoff rate for all jobs deployed"
  default     = 2
}

variable "security_config_id" {
  description = "Glue security configuration id"
}

variable "connections" {
  description = "Glue job connections"
  default     = []
}

variable "script_bucket" {
  description = "Name of the bucket where the job script should be upload"
}

variable "glue_path" {
  description = "Glue job extra py files s3 paths"
}

variable "policy_variables" {
  type        = map(string)
  description = "Policy variables for executor policy"
  default     = {}
}

variable "job_name" {
  type        = string
  description = "Glue job name"
}

variable "job_arguments" {
  type        = map(string)
  description = "Glue job arguments"
  default     = {}
}
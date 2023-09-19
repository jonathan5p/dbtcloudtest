variable "base_naming" {
  default = null
}

variable "project_prefix"{
    default = ""
}

variable "purpose" {
  description = "Glue job purpose"
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

variable "script_location" {
  description = "Glue job script location"
}

variable "job_conf" {
  description = "Glue job spark configurations settings"
}

variable "extra_jars" {
  description = "Glue job extra jar files s3 paths"
}

variable "extra_py_files" {
  description = "Glue job extra py files s3 paths"
}

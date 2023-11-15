variable "s3_bucket" {
  description = "Name of the s3 bucket"
}

variable "s3_bucket_versioning" {
  description = "Bucket versioning enable flag"
  default = false
}

variable "s3_bucket_tags" {
  description = "tags associated with s3 bucket"
}

variable "s3_bucket_key_id" {
  description = "encryption key associated with the bucket"
  default = null
}

variable "s3_bucket_key_arn" {
  description = "arn of the encryption key associated with the bucket"
  default = null
}

variable "s3_bucket_tmp_expiration_days" {
  description = "Expiration lifecycle policy for all objects store in the tmp prefix of the s3 bucket"
  default = 15
}

variable "s3_bucket_objects_expiration_days" {
  description = "Expiration lifecycle policy for all objects store in the s3 bucket except tmp"
  default = 180
}

variable "s3_bucket_objects_transition_days" {
  description = "Transition to Inteligent Tiering lifecycle policy for all objects store in the s3 bucket except tmp"
  default = 30
}
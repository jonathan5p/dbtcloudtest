variable "key_name" {
  type        = string
  description = "KMS key alias"
}

variable "key_tags" {
  type        = map(string)
  description = "KMS key tags"
}

variable "key_description" {
  type        = string
  description = "KMS key description"
}

variable "aws_account_number" {
  type        = string
  description = ""
}

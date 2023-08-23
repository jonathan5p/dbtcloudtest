terraform {
  required_version = ">= 1.5.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.5.0, < 5.10.0"
    }
  }
  backend "s3" {
  }
}
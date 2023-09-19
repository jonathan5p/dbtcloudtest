terraform {
  required_version = ">= 1.5.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.5.0, < 5.10.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "2.4.0"
    }
  }
  backend "s3" {
  }
}
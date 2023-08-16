terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.71, < 4.0"
    }
  }
  backend "s3" {
  }
}
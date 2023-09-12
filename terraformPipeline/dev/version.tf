terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.71, < 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.19.1"
    }
  }

  backend "s3" {
    #S3 bucket for state data
    bucket = "aue1s1z1s3bterraform-state"

    # add workspace prefix to key path in S3 bucket, this adds /workspace:/{workspace name}/ to
    # the key path.
    # Do NOT change as access to the different environments are controlled by this settings.  Any
    # changes will cause terraform executions to fail.
    workspace_key_prefix = "workspace:"
    # key reflects the object path specific to this terraform instance
    #     "{application group}/{repo  }/{folder }/{subfolder }/{state file name}"
    key = "ds/bdmp-oidh/oidh-cicd/terraform.tfstate"

    # state bucket region
    region = "us-east-1"

    # DynamoDB for logging to prevent concurrent execution
    dynamodb_table    = "aue1s1z1ddtterraform-state"
    dynamodb_endpoint = "https://dynamodb.us-east-1.amazonaws.com/"
    encrypt           = true

    # AWS credentials for state and locking, has to be defined in your credentials file with
    # that profile name.  See https://wiki.brightmls.com/display/MRIS/AWS+Role+Shortcuts for more
    # information
    profile = "bright_tf_admin"

  }
}
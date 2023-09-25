data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

module "sqs_register_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sqs"
  purpose     = join("", [var.project_prefix, "-", var.queue_name])
}

module "sqs_register_dlq_data_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "sqs"
  purpose     = join("", [var.project_prefix, "-", var.queue_name, "dlq"])
}

resource "aws_sqs_queue" "register" {
  name                       = module.sqs_register_data_naming.name
  visibility_timeout_seconds = 60
  tags                       = module.sqs_register_data_naming.tags
  kms_master_key_id          = var.project_objects.data_key_id    
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.register_dlq.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "register_dlq" {
  name                       = module.sqs_register_dlq_data_naming.name
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600
  kms_master_key_id          = var.project_objects.data_key_id
  tags                       = module.sqs_register_dlq_data_naming.tags
}

resource "aws_sqs_queue_policy" "register" {
  queue_url = aws_sqs_queue.register.id
  policy    = data.aws_iam_policy_document.sqs_register.json
}

data "aws_iam_policy_document" "sqs_register" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage"
    ]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    resources = [
      aws_sqs_queue.register.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:*:*:${var.project_objects.bucket_id}"]
    }
  }
}

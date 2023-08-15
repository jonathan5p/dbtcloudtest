module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

module "cpl_approval_sns_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "snr"
  purpose     =  join("", [var.project_prefix, "-${var.datapipeline_name}" ,"-approval"])
}

resource "aws_sns_topic" "approval" {
  count = var.sns_notification_create_approval ? 1 : 0
  name = module.cpl_approval_sns_naming.name
  tags = module.cpl_approval_sns_naming.tags
}

resource "aws_ssm_parameter" "approval_notification_parameter" {
  count       = var.sns_notification_create_approval ? 1 : 0
  name        = "/parameter/${var.site}/${var.environment_devops}/${var.datapipeline_name}/sns/approval_notification"
  type        = "SecureString"
  value       = aws_sns_topic.approval[0].arn
  description = "Arn for the notification approval sns"
  overwrite   = true
}
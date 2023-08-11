resource "aws_sns_topic" "approval" {
  count = var.sns_notification_create_approval ? 1 : 0
  name = "${var.datapipeline_name}-approval"
}

resource "aws_ssm_parameter" "approval_notification_parameter" {
  count       = var.sns_notification_create_approval ? 1 : 0
  name        = "/${var.datapipeline_name}/sns/approval_notification"
  type        = "SecureString"
  value       = aws_sns_topic.approval[0].arn
  description = "Arn for the notification approval sns"
  overwrite   = true
}
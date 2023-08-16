output "sns_topic_approval" {
    #value = aws_sns_topic.approval[0].arn
    value = aws_sns_topic.approval.arn
}
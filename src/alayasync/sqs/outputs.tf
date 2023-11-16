output "sqs_register_queue_arn" {
  value = aws_sqs_queue.register.arn
}

output "sqs_register_dlq_arn" {
  value = aws_sqs_queue.register_dlq.arn
}

output "sqs_names" {
  value = {
    "registration" : aws_sqs_queue.register.name
    "registration_dlq" : aws_sqs_queue.register_dlq.name
  }
}
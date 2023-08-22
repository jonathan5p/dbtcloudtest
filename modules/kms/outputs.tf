output "key_id" {
  value = aws_kms_key.kms_key.key_id
}

output "key_arn" {
  value = aws_kms_key.kms_key.arn
}

output "key_name" {
  value = aws_kms_alias.key_alias.name
}
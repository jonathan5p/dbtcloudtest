output "s3_code_bucket_arn"{
    value = aws_s3_bucket.output.arn
}

output "s3_code_bucket_name" {
    value = aws_s3_bucket.output.id
}

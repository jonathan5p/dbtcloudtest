output "job_id" {
  value = aws_glue_job.glue_job.id
}

output "job_arn" {
  value = aws_glue_job.glue_job.arn
}

output "role_arn" {
  value = aws_iam_role.glue_job_role.arn
}

output "role_name" {
  value = aws_iam_role.glue_job_role.name
}
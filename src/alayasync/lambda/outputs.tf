output "functions_mapping" {
  value = {
    "ecs_start" : module.lambda_alaya_sync_ecs_start.lambda_arn
    "ecs_status" : module.lambda_alaya_sync_ecs_status.lambda_arn
    "schedule_lambda" : module.lambda_alaya_sync_scheduling.lambda_arn
    "reduce_lambda" : module.lambda_alaya_sync_reduce.lambda_arn
  }
}
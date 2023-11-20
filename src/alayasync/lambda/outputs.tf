output "functions_mapping" {
  value = {
    "async_lambda" : module.lambda_alaya_sync_async.lambda_arn
    "start_task" : module.lambda_alaya_sync_start_task.lambda_arn
    "status_task" : module.lambda_alaya_sync_status_task.lambda_arn
    "register_lambda" : module.lambda_alaya_sync_register.lambda_arn
    "schedule_lambda" : module.lambda_alaya_sync_scheduling.lambda_arn
    "reduce_lambda" : module.lambda_alaya_sync_reduce.lambda_arn
  }
}
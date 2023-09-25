output "functions_mapping" {
    value = {
       "register_lambda": module.lambda_alaya_sync_register.lambda_arn
       "schedule_lambda": module.lambda_alaya_sync_scheduling.lambda_arn
       "processing_lambda": module.lambda_alaya_sync_processing.lambda_arn
       "reduce_lambda": module.lambda_alaya_sync_reduce.lambda_arn
    }
}
output "functions_mapping" {
  value = {
    "execution_lambda" : module.lambda_alaya_sync_execution.lambda_arn
  }
}
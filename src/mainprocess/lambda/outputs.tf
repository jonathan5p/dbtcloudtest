output "functions_mapping" {
  value = {
    "config_loader" : module.lambda_config_loader
    "staging_agent" : module.lambda_staging_agent
    "staging_office" : module.lambda_staging_office
  }
}
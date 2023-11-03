output "layers_mapping" {
    value = {
       "alaya_utils_layer": aws_lambda_layer_version.alaya_utils_layer.arn
       "alaya_sync_layer": aws_lambda_layer_version.alaya_sync_layer.arn
    }
}
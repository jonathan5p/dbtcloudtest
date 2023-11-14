locals {
  alaya_sync_layer  = "${var.site}${var.environment}${var.zone}lay${var.project_app_group}${var.project_prefix}"
  alaya_utils_layer = "${var.site}${var.environment}${var.zone}lay${var.project_app_group}${var.project_prefix}-utils"
}

data "archive_file" "alaya_utils_layer" {
  type        = "zip"
  source_dir  = "${path.module}/src/utils"
  output_path = "${path.module}/src/utils.zip"
}

resource "aws_lambda_layer_version" "alaya_utils_layer" {
  filename   = "${path.module}/src/utils.zip"
  layer_name = local.alaya_utils_layer

  compatible_runtimes = ["python3.9"]
  source_code_hash    = data.archive_file.alaya_utils_layer.output_base64sha256
}

data "archive_file" "alaya_sync_layer" {
  type        = "zip"
  source_dir  = "${path.module}/src/sync"
  output_path = "${path.module}/src/sync.zip"
}

resource "aws_lambda_layer_version" "alaya_sync_layer" {
  filename   = "${path.module}/src/sync.zip"
  layer_name = local.alaya_sync_layer

  compatible_runtimes = ["python3.9"]
  source_code_hash    = data.archive_file.alaya_sync_layer.output_base64sha256
}
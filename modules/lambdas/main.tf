data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  lambda_runtime = "python3.9"
  lambda_handler = "lambda_function.lambda_handler"
  local_objects = {
    "region" : "${data.aws_region.current.name}"
    "account_id" : "${data.aws_caller_identity.current.account_id}"
  }
}

module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

module "iro_lambda_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", var.lambda_name])
}

module "ipl_lambda_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", var.lambda_name])
}

resource "aws_iam_role" "lambda" {
  name               = module.iro_lambda_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = module.iro_lambda_naming.tags
}

data "template_file" "policy" {
  template = file("${var.lambda_path}/${var.lambda_name}/policy.json.tpl")
  vars = merge(var.policy_variables, local.local_objects,
    {
      "lambda_name" = "${module.lmb_function_naming.name}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_policy" "policy" {
  name   = module.ipl_lambda_policy_naming.name
  policy = data.template_file.policy.rendered
}

data "archive_file" "source_code" {
  type        = "zip"
  source_file = "${var.lambda_path}/${var.lambda_name}/lambda_function.py"
  output_path = "${var.lambda_path}/${var.lambda_name}.zip"
}

module "lmb_function_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "lmb"
  purpose     = join("", [var.project_prefix, "-", var.lambda_name])
}

resource "aws_lambda_function" "executor" {
  function_name    = module.lmb_function_naming.name
  description      = var.lambda_name
  role             = aws_iam_role.lambda.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = var.memory_size
  timeout          = var.timeout
  layers           = var.layers
  source_code_hash = data.archive_file.source_code.output_base64sha256
  filename         = data.archive_file.source_code.output_path
  tags             = module.lmb_function_naming.tags

  environment {
    variables = var.environment_variables
  }
}

module "lmb_cloudwatch_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwg"
  purpose     = join("", [var.project_prefix, "-", var.lambda_name])
}

resource "aws_cloudwatch_log_group" "register" {
  name              = "/aws/lambda/${module.lmb_function_naming.name}"
  retention_in_days = 30
  tags              = module.lmb_cloudwatch_naming.tags
}
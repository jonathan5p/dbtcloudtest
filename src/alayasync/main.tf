module "sqs" {
    source = "./sqs"

    environment         = var.environment
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    queue_name          = "alayasyncregister"
    tier                = var.tier
    zone                = var.zone

    project_objects     = var.project_objects
}

module "dynamo" {
    source = "./dynamo"

    environment         = var.environment
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    table_name          = "alayasync"  
    tier                = var.tier
    zone                = var.zone

    project_objects     = var.project_objects

}

module "lambdas" {
    source = "./lambda"
    
    environment         = var.environment
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    project_objects     = merge(var.project_objects, 
    {
        "dynamo_table_register" = "${module.dynamo.table_naming.name}"
    })
}

module "step_functions" {
    source = "./stepfunction"

    environment         = var.environment
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    policy_variables    = merge(var.project_objects,module.lambdas.functions_mapping)
}

module "lambdas_execution" {
    source = "./lambda_execution"
    
    environment         = var.environment
    project_app_group   = var.project_app_group
    project_ledger      = var.project_ledger
    project_prefix      = var.project_prefix
    site                = var.site
    tier                = var.tier
    zone                = var.zone

    project_objects     = merge(var.project_objects, 
    {
        "dynamo_table_register" = "${module.dynamo.table_naming.name}",
        "sfn_alaya_sync" = "${module.step_functions.sfn_alaya_sync_arn}"
    })
}

resource "aws_lambda_event_source_mapping" "register" {
  event_source_arn = module.sqs.sqs_register_queue_arn
  function_name    = module.lambdas.functions_mapping.register_lambda
  batch_size       = 1
  enabled          = true
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromS3BucketToLambda"
  action        = "lambda:InvokeFunction"
  function_name = module.lambdas_execution.functions_mapping.execution_lambda
  principal     = "s3.amazonaws.com"
  source_arn    = var.project_objects.bucket_arn
}

resource "aws_s3_bucket_notification" "register" {
  bucket = var.project_objects.bucket_id

  queue {
    queue_arn = module.sqs.sqs_register_queue_arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix = "consume_data/aue1d1z1gldoidhoidh_gluedb/individuals_test"
    filter_suffix = ".parquet"
  }

  lambda_function {
    lambda_function_arn = module.lambdas_execution.functions_mapping.execution_lambda
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "consume_data/resultData/executions/"
    filter_suffix       = ".log"
  }

  queue {
    queue_arn = module.sqs.sqs_register_queue_arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix = "consume_data/aue1d1z1gldoidhoidh_gluedb/organizations_test"
    filter_suffix = ".parquet"
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

module "cwa_alaya_sync_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwa"
  purpose     = join("", [var.project_prefix, "-", "alayasync"])
}

resource "aws_cloudwatch_metric_alarm" "sfn" {
  alarm_name                = module.cwa_alaya_sync_naming.name
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "ExecutionsFailed"
  namespace                 = "AWS/States"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 0
  alarm_description         = "Monitors failed executions for AlayaSync step function"
  treat_missing_data        = "ignore"
  insufficient_data_actions = []
  tags                      = module.cwa_alaya_sync_naming.tags
  dimensions = {
    StateMachineArn=module.step_functions.sfn_alaya_sync_arn
  }
}

module "cwa_alaya_sync_register_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "cwa"
  purpose     = join("", [var.project_prefix, "-", "alayasyncregister"])
}

resource "aws_cloudwatch_metric_alarm" "register" {
  alarm_name                = module.cwa_alaya_sync_register_naming.name
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 0
  alarm_description         = "Monitors Failed registration processes for AlayaSync"
  treat_missing_data        = "ignore"
  insufficient_data_actions = []
  tags                      = module.cwa_alaya_sync_register_naming.tags
  dimensions = {
    QueueName=module.sqs.sqs_names.registration
  }
}
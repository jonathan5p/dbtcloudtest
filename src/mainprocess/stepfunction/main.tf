module "stepfunction" {
  #source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//step_functions?ref=dev"
  source = "git::ssh://git@github.com/BrightMLS/bdmp-terraform-pipeline.git//step_functions?ref=dev"

  environment       = var.environment
  sfn_name          = "mainprocess"
  sfn_path          = "../src/mainprocess/stepfunction"
  project_app_group = var.project_app_group
  project_ledger    = var.project_ledger
  project_prefix    = var.project_prefix
  site              = var.site
  tier              = var.tier
  zone              = var.zone

  policy_variables = var.policy_variables
}

# Cron trigger execution role
module "trigger_role_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "iro"
  purpose     = join("", [var.project_prefix, "-", "etltrigger"])
}
resource "aws_iam_role" "crontrigger_role" {
  name = module.trigger_role_naming.name
  tags = module.trigger_role_naming.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Sid    = "CronTriggerAssumeRole"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

# Cron trigger
module "cron_trigger_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "cwr"
  purpose     = join("", [var.project_prefix, "-", "etltrigger"])
}

resource "aws_cloudwatch_event_rule" "cron_trigger" {
  name                = module.cron_trigger_naming.name
  tags                = module.cron_trigger_naming.tags
  is_enabled          = var.cron_trigger_enabled
  schedule_expression = var.cron_schedule
}

resource "aws_cloudwatch_event_target" "etl_sfn" {
  rule      = aws_cloudwatch_event_rule.cron_trigger.name
  target_id = "StartStateMachine"
  arn       = module.stepfunction.sfn_arn
  role_arn  = aws_iam_role.crontrigger_role.arn
}

# Cron trigger policies

data "aws_iam_policy_document" "cron_trigger_policy" {
  statement {
    sid       = "stfexecaccess"
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [module.stepfunction.sfn_arn]
  }
}

module "cron_trigger_policy_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "ipl"
  purpose     = join("", [var.project_prefix, "-", "etltrigger"])
}
resource "aws_iam_policy" "cron_trigger_policy" {
  name        = module.cron_trigger_policy_naming.name
  tags        = module.cron_trigger_policy_naming.tags
  description = "IAM Policy for the EventBridge cron trigger of the dedupe process etl"
  policy      = data.aws_iam_policy_document.cron_trigger_policy.json
}

resource "aws_iam_role_policy_attachment" "cron_trigger_policy_attachement" {
  role       = aws_iam_role.crontrigger_role.name
  policy_arn = aws_iam_policy.cron_trigger_policy.arn
}

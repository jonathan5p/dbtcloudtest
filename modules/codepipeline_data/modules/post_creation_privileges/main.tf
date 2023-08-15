module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

data "aws_iam_policy_document" "cbd_build" {
    statement {
      effect = "Allow"
      actions = [
        "codebuild:CreateReportGroup",
        "codebuild:CreateReport",
        "codebuild:UpdateReport",
        "codebuild:BatchPutTestCases"
    ]
      resources = ["arn:aws:codebuild:*:${var.aws_account_number_devops}:report-group/${var.codepipeline_cbd_build_naming}*"]
  }
}

module "irp_cbd_build_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  purpose     = join("", ["cbdbuild", var.project_prefix, "-reports-", var.environment_dev])
}

resource "aws_iam_policy" "cbd_build" {
  name        = module.irp_cbd_build_naming.name
  description = join(" ", ["Standard Build Access policy for", module.irp_cbd_build_naming.name])
  policy      = data.aws_iam_policy_document.cbd_build.json
}

module "iro_cpl_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", ["cpl", var.project_prefix])
}

data "aws_iam_policy_document" "cpl_access" {
  statement {
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [
      var.codepipeline_codebuild_project_build_arn,
      var.codepipeline_codebuild_project_provision_arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      var.dev_deployment_role #module.dev_deployment_role.provision_role_arn
    ]
  }
}

module "ipl_cpl_access_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.iro_cpl_naming
  type        = "ipl"
  purpose     = join("", ["cplaccess", var.project_prefix, "-cross-account-", var.environment_dev])
}

resource "aws_iam_policy" "cpl_access" {
  name   = module.ipl_cpl_access_naming.name
  policy = data.aws_iam_policy_document.cpl_access.json
}

resource "aws_iam_role_policy_attachment" "cdb_build_access" {
  role       = var.iam_role_cbd_build_name
  policy_arn = aws_iam_policy.cbd_build.arn
}

resource "aws_iam_role_policy_attachment" "cdb_cpl_access" {
  role       = var.iam_role_cbd_provision_name
  policy_arn = aws_iam_policy.cpl_access.arn
}

resource "aws_iam_role_policy_attachment" "cpl_access" {
  role       = var.iam_role_cpl_name
  policy_arn = aws_iam_policy.cpl_access.arn
}
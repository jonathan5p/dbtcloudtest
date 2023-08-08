module "base_naming" {
  source    = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  app_group = var.project_app_group
  env       = var.environment_devops
  ledger    = var.project_ledger
  site      = var.site
  tier      = var.tier
  zone      = var.zone
}

# ------------------------------------------------------------------------------
# Create Assume CodeBuild Assume Role Policy
# ------------------------------------------------------------------------------
module "iro_cbd_assume_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", ["cbdassume", var.project_prefix])
}

module "iro_cbd_provision_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", ["cbdprovision", var.project_prefix])
}

data "aws_iam_policy_document" "assume_cbd_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cbd_build" {
  name               = module.iro_cbd_assume_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume_cbd_role.json
  tags               = module.iro_cbd_assume_naming.tags
}

resource "aws_iam_role" "cbd_provision" {
  name               = module.iro_cbd_provision_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume_cbd_role.json
  tags               = module.iro_cbd_provision_naming.tags
}

# ------------------------------------------------------------------------------
# Create Assume CodePipeline Assume Role Policy
# ------------------------------------------------------------------------------
module "iro_cpl_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "iro"
  purpose     = join("", ["cpl", var.project_prefix])
}

data "aws_iam_policy_document" "assume_cpl_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cpl_access" {
  statement {
    effect = "Allow"
    actions = [
      "codestar-connections:Get*",
      "codestar-connections:List*",
      "codestar-connections:UseConnection",
    ]
    resources = [var.codestar_github_connection]
  }
}

module "ipl_cpl_access_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.iro_cpl_naming
  type        = "ipl"
  purpose     = join("", ["cplaccess", var.project_prefix])
}

resource "aws_iam_policy" "cpl_access" {
  name   = module.ipl_cpl_access_naming.name
  policy = data.aws_iam_policy_document.cpl_access.json
}

resource "aws_iam_role" "cpl_role" {
  name               = module.iro_cpl_naming.name
  assume_role_policy = data.aws_iam_policy_document.assume_cpl_role.json
  tags               = module.iro_cpl_naming.tags
}

resource "aws_iam_role_policy_attachment" "cpl_access" {
  role       = aws_iam_role.cpl_role.name
  policy_arn = aws_iam_policy.cpl_access.arn
}

# ------------------------------------------------------------------------------
# Create Regular Access controls for all Builds
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "cbd_build" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
        var.s3_code_bucket_arn,
        "${var.s3_code_bucket_arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:*:${var.aws_account_number_devops}:parameter/secure/${var.site}/c1/codebuild/*",
      "arn:aws:ssm:*:${var.aws_account_number_devops}:parameter/parameter/${var.site}/c1/codebuild/*"
    ]
  }
}

module "irp_cbd_build_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = module.base_naming
  type        = "irp"
  purpose     = join("", ["cbdbuild", var.project_prefix])
}

resource "aws_iam_policy" "cbd_build" {
  name        = module.irp_cbd_build_naming.name
  description = join(" ", ["Standard Build Access policy for", module.irp_cbd_build_naming.name])
  policy      = data.aws_iam_policy_document.cbd_build.json
}

resource "aws_iam_role_policy_attachment" "cdb_build_access" {
  role       = aws_iam_role.cbd_build.name
  policy_arn = aws_iam_policy.cbd_build.arn
}

resource "aws_iam_role_policy_attachment" "cdb_provision_access" {
  role       = aws_iam_role.cbd_provision.name
  policy_arn = aws_iam_policy.cbd_build.arn
}

resource "aws_iam_role_policy_attachment" "cdb_cpl_access" {
  role       = aws_iam_role.cbd_provision.name
  policy_arn = aws_iam_policy.cpl_access.arn
}

resource "aws_iam_role_policy_attachment" "cpl_build_access" {
  role       = aws_iam_role.cpl_role.name
  policy_arn = aws_iam_policy.cbd_build.arn
}

# SSM parameters
resource "aws_ssm_parameter" "iam_role_cbd_build_arn" {
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_build_arn"
  type        = "SecureString"
  value       = aws_iam_role.cbd_build.arn
  description = "Arn for the role used in the build step"
  overwrite   = true
}

resource "aws_ssm_parameter" "iam_role_cbd_build_name" {
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_build_name"
  type        = "SecureString"
  value       = aws_iam_role.cbd_build.name
  description = "Name for the role used in the build step"
  overwrite   = true
}

resource "aws_ssm_parameter" "iam_role_cbd_provision_arn" {
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_provision_arn"
  type        = "SecureString"
  value       = aws_iam_role.cbd_provision.arn
  description = "Arn for the role used in the provision step"
  overwrite   = true
}

resource "aws_ssm_parameter" "iam_role_cbd_provision_name" {
  name        = "/${var.datapipeline_name}/iam/iam_role_cbd_provision_name"
  type        = "SecureString"
  value       = aws_iam_role.cbd_provision.name
  description = "Name for the role used in the provision step"
  overwrite   = true
}

resource "aws_ssm_parameter" "iam_role_cpl_arn" {
  name        = "/${var.datapipeline_name}/iam/iam_role_cpl_arn"
  type        = "SecureString"
  value       = aws_iam_role.cpl_role.arn
  description = "Arn for the role used in codepipeline"
  overwrite   = true
}

resource "aws_ssm_parameter" "iam_role_cpl_name" {
  name        = "/${var.datapipeline_name}/iam/iam_role_cpl_name"
  type        = "SecureString"
  value       = aws_iam_role.cpl_role.name
  description = "Name for the role used in codepipeline"
  overwrite   = true
}
data "aws_iam_policy_document" "key_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_number}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
    sid       = "rooutaccount"
  }

  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "glue.amazonaws.com",
        "lambda.amazonaws.com",
        "athena.amazonaws.com",
        "logs.amazonaws.com"
      ]
    }
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
      "kms:Describe*"
    ]
    resources = ["*"]
    sid       = "services"
  }

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
      "kms:Decrypt"
    ]
    resources = ["*"]
    sid       = "s3"
  }
}

resource "aws_kms_key" "kms_key" {
  description              = var.key_description
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  tags                     = var.key_tags
  policy                   = data.aws_iam_policy_document.key_policy.json
}

resource "aws_kms_alias" "key_alias" {
  name          = join("/", ["alias", var.key_name])
  target_key_id = aws_kms_key.kms_key.key_id
}

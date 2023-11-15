locals{
  kms_key_count = var.s3_bucket_key_id == null?0:1
}

#------------------------------------------------------------------------------
# Bucket defaults
#------------------------------------------------------------------------------

resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.s3_bucket
  tags   = var.s3_bucket_tags
}

resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = var.s3_bucket_versioning?"Enabled":"Disabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "s3_ownership" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

#------------------------------------------------------------------------------
# Default Encryption
#------------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "default_encryption" {
  count = var.s3_bucket_key_id == null?1:0
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#------------------------------------------------------------------------------
# KMS Encryption
#------------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "kms_encryption" {
  count = local.kms_key_count
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.s3_bucket_key_id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "security_policy" {
  count = local.kms_key_count
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    effect = "Deny"
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
    condition {
      test     = "ForAnyValue:StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = ["${var.s3_bucket_key_arn}"]
    }
  }

  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.s3_bucket.arn}", "${aws_s3_bucket.s3_bucket.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = [false]
    }
  }
}

resource "aws_s3_bucket_policy" "security_policy" {
  count = local.kms_key_count
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.security_policy[0].json
}

#------------------------------------------------------------------------------
# KMS Encryption
#------------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  depends_on = [aws_s3_bucket_versioning.s3_bucket_versioning]
  bucket     = aws_s3_bucket.s3_bucket.id

  rule {
    id = "bucket_lifecycle"
    expiration {
      days = var.s3_bucket_objects_expiration_days
    }
    filter {}
    status = "Enabled"
    transition {
      days          = var.s3_bucket_objects_transition_days
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id = "tmp"
    filter {
      prefix = "tmp/"
    }
    expiration {
      days = var.s3_bucket_tmp_expiration_days
    }
    status = "Enabled"
  }

  rule {
    id = "versions_config"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    status = "Enabled"
  }

  rule {
    id = "tmp_versions"
    filter {
      prefix = "tmp/"
    }
    noncurrent_version_expiration {
      noncurrent_days = 15
    }
    status = "Enabled"
  }
}

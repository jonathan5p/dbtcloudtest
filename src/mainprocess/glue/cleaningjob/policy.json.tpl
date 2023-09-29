{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect":"Allow",
            "Action": [
                "s3:Abort*",
                "s3:DeleteObject*",
                "s3:GetBucket*",
                "s3:GetObject*",
                "s3:List*",
                "s3:PutObject",
                "s3:PutObjectLegalHold",
                "s3:PutObjectRetention",
                "s3:PutObjectTagging",
                "s3:PutObjectVersionTagging"],
            "Resource": [
                "${data_bucket_arn}",
                "${data_bucket_arn}/*",
                "${glue_bucket_arn}",
                "${glue_bucket_arn}/*",
                "${artifacts_bucket_arn}",
                "${artifacts_bucket_arn}/*"]
        },
        {
            "Effect":"Allow",
            "Action": ["logs:AssociateKmsKey"],
            "Resource": ["arn:aws:logs:${region}:${account_id}:log-group:/aws-glue/jobs/*"]
        }
    ]
}
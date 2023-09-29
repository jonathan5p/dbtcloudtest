{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:PutObjectVersionTagging",
                "s3:PutObjectTagging",
                "s3:PutObjectRetention",
                "s3:PutObjectLegalHold",
                "s3:PutObject",
                "s3:List*",
                "s3:GetObject*",
                "s3:GetBucket*",
                "s3:DeleteObject*",
                "s3:Abort*"
            ],
            "Effect": "Allow",
            "Resource": [
                "${data_bucket_arn}",
                "${data_bucket_arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action" : [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ],
            "Resource" : [
                "arn:aws:logs:${region}:${account_id}:log-group:/aws/lambda/*"
              ]
        }
    ]
}
{
  "Version": "2012-10-17",
  "Statement" : [
    {
      "Effect": "Allow",
      "Action" : [
        "s3:GetBucket*",
        "s3:GetObject*",
        "s3:List*"
      ],
      "Resource" : [
        "${artifacts_bucket_arn}",
        "${artifacts_bucket_arn}/*"
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
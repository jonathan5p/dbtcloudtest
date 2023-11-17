{
  "Version": "2012-10-17",
  "Statement" : [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "${schedule_lambda}",
        "${reduce_lambda}",
        "${start_task}",
        "${status_task}"
      ]
    },
    {
      "Effect": "Allow",
      "Action" : [
        "s3:GetObject",
        "s3:GetBucketAcl",
        "s3:ListBucket",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:DeleteObject"
      ],
      "Resource" : [
        "arn:aws:s3:::${bucket_id}/consume_data/resultData",
        "arn:aws:s3:::${bucket_id}/consume_data/resultData/*"
      ]
    },
    {
      "Effect" : "Allow",
      "Action" : [
        "states:StartExecution"
      ],
      "Resource" : [
        "arn:aws:states:${region}:${account_id}:stateMachine:${sfn_name}"
      ]
    },
    {
        "Effect" : "Allow",
        "Action": [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant"
        ],
        "Resource" : [
          "${data_key_arn}"
        ]
      }
  ]
}
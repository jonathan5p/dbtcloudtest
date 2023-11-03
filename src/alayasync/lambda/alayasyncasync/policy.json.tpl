{
  "Version": "2012-10-17",
  "Statement" : [
    {
      "Effect": "Allow",
      "Action" : [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource" : [
        "arn:aws:logs:${region}:${account_id}:log-group:/aws/lambda/*"
      ]
    },
    {
      "Effect" : "Allow",
      "Action" : [
        "dynamodb:BatchGetItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:GetRecords",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem",
        "dynamodb:PutItem"
      ],
      "Resource" : [
        "arn:aws:dynamodb:${region}:${account_id}:table/${dynamo_table_register}",
        "arn:aws:dynamodb:${region}:${account_id}:table/${dynamo_table_register}/*",
        "arn:aws:dynamodb:${region}:${account_id}:table/${dynamo_table_async}",
        "arn:aws:dynamodb:${region}:${account_id}:table/${dynamo_table_async}/*"
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
    },
    {
      "Effect" : "Allow",
      "Action" : [
        "ecs:RunTask"
      ],
      "Resource": [
        "arn:aws:ecs:${region}:${account_id}:task-definition/*"
      ]
    },
    {
      "Effect" : "Allow",
      "Action" : [
        "ecs:DescribeTasks"
      ],
      "Resource": [
        "arn:aws:ecs:${region}:${account_id}:task/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:DeleteObject*",
        "s3:GetObject*",
        "s3:GetBucketAcl",
        "s3:ListBucket",
        "s3:PutObject*"
      ],
      "Resource" : [
        "arn:aws:s3:::${bucket_id}",
        "arn:aws:s3:::${bucket_id}/*",
        "arn:aws:s3:::${athena_bucket_id}/*",
        "arn:aws:s3:::${athena_bucket_id}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetTable",
        "glue:BatchCreatePartition",
        "glue:UpdateTable",
        "glue:CreateTable",
        "glue:GetPartitions",
        "glue:GetPartition",
        "glue:GetDatabases"
      ],
      "Resource": [
        "arn:aws:glue:${region}:${account_id}:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "events:PutEvents"
      ],
      "Resource" : [
        "arn:aws:events:${region}:${account_id}:event-bus/default"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:GetQueryResultsStream"
      ],
      "Resource": [
        "arn:aws:athena:${region}:${account_id}:workgroup/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/*"
      ]
    }
  ]
}
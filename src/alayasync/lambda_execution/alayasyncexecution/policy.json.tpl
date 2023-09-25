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
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ListQueues",
        "sqs:ListDeadLetterSourceQueues",
        "sqs:ListQueueTags",
        "sqs:ReceiveMessage",
        "sqs:SendMessage",
        "sqs:SendMessageBatch"
      ],
      "Resource" : [
        "arn:aws:sqs:${region}:${account_id}:*"
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
        "arn:aws:dynamodb:${region}:${account_id}:table/${dynamo_table_register}/*"
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
        "states:StartExecution"
      ],
      "Resource" : [
        "${sfn_alaya_sync}"
      ]
    }
  ]
}
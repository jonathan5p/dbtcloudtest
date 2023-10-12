{
  "Version": "2012-10-17",
  "Statement" : [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "${config_loader_lambda}",
        "${config_loader_lambda}:*",
        "${staging_agent_lambda}",
        "${staging_agent_lambda}:*",
        "${staging_office_lambda}",
        "${staging_office_lambda}:*"
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
      "Effect": "Allow",
      "Action": [
        "glue:BatchStopJobRun",
        "glue:GetJobRun",
        "glue:GetJobRuns",
        "glue:StartJobRun",
        "glue:StartCrawler"
      ],
      "Resource": [
        "arn:aws:glue:${region}:${account_id}:job/${glue_ingest_job}",
        "arn:aws:glue:${region}:${account_id}:job/${glue_cleaning_job}",
        "arn:aws:glue:${region}:${account_id}:job/${glue_ind_dedup_job}",
        "arn:aws:glue:${region}:${account_id}:job/${glue_org_dedup_job}",
        "arn:aws:glue:${region}:${account_id}:job/${glue_geoinfo_job}",
        "arn:aws:glue:${region}:${account_id}:crawler/${glue_staging_crawler}"
      ]
    }
  ]
}
# Project parameters
zone               = "z1"
environment_devops = "c1"

# S3 parameters
s3_bucket_tmp_expiration_days     = 15
s3_bucket_objects_expiration_days = 180
s3_bucket_objects_transition_days = 30

# Data KMS Admins and Users
kms_data_admins = ["arn:aws:iam::497607366324:role/aue1q1z1irodevopsqueryeadmin"]
kms_data_users  = ["arn:aws:iam::497607366324:role/databricks-workspace-stack-access-data-buckets"]

# Glue KMS Admins and Users
kms_glue_admins = ["arn:aws:iam::497607366324:role/aue1q1z1irodevopsqueryeadmin"]

# Eventbridge trigger parameters
cron_schedule = "cron(0 23 * * ? *)"
ecs_subnets = "subnet-0112c4c44ce9649c2"
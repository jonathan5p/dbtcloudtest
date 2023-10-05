# Project parameters
zone               = "z1"
environment_devops = "c1"

# S3 parameters
s3_bucket_tmp_expiration_days     = 15
s3_bucket_objects_expiration_days = 180
s3_bucket_objects_transition_days = 30

# Eventbridge trigger parameters
cron_schedule = "cron(0 23 * * ? *)"

ecs_subnets = "subnet-0112c4c44ce9649c2"
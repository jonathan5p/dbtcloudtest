# Project parameters
zone               = "z1"
environment_devops = "c1"

# S3 parameters
s3_bucket_tmp_expiration_days     = 15
s3_bucket_objects_expiration_days = 180
s3_bucket_objects_transition_days = 30

# Glue geosvc subnet id
glue_geosvc_subnetid = "subnet-0edd5c963fca279cf"

# Eventbridge trigger parameters
cron_schedule = "cron(0 23 * * ? *)"

# ECS parameters
ecs_subnets   = "subnet-0edd5c963fca279cf"
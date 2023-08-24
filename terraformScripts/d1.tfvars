# Project parameters
zone                             = "z1"
environment_devops               = "c1"

# S3 parameters
s3_bucket_tmp_expiration_days     = 15
s3_bucket_objects_expiration_days = 180
s3_bucket_objects_transition_days = 30

# Lambda parameters
lambda_reserved_concurrent_executions = 10
lambda_timeout                        = 300
lambda_memory_size                    = 256
lambda_retry_max_attempts             = 3
lambda_retry_interval                 = 1
lambda_retry_backoff_rate             = 2

# Glue parameters
glue_max_concurrent_runs         = 4
glue_timeout                     = 60
glue_worker_type                 = "G.1X"
glue_number_of_workers           = 10
glue_retry_max_attempts          = 3
glue_retry_interval              = 2
glue_retry_backoff_rate          = 2
glue_redshift_conn_subnet_id     = "subnet-0112c4c44ce9649c2"
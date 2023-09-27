#------------------------------------------------------------------------------
# Upload S3 Data
#------------------------------------------------------------------------------

resource "aws_s3_object" "glue_jars" {
  bucket                 = var.project_objects.glue_bucket.bucket_id
  for_each               = fileset("../src/mainprocess/glue/jars", "**")
  key                    = join("/",["jars",each.value])
  source                 = "../src/mainprocess/glue/jars/${each.value}"
  server_side_encryption = "AES256"
  etag                   = filemd5("../src/mainprocess/glue/jars/${each.value}")
  bucket_key_enabled = true
}

resource "aws_s3_object" "glue_scripts" {
  bucket                 = var.project_objects.glue_bucket.bucket_id
  for_each               = fileset("../src/mainprocess/glue/scripts", "**")
  key                    = join("/",["scripts",each.value])
  source                 = "../src/mainprocess/glue/scripts/${each.value}"
  server_side_encryption = "AES256"
  etag                   = filemd5("../src/mainprocess/glue/scripts/${each.value}")
  bucket_key_enabled = true
}

#------------------------------------------------------------------------------
# Glue DB
#------------------------------------------------------------------------------

module "glue_db_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gld"
  purpose     = join("", [var.project_prefix, "_", "gluedb"])
}

resource "aws_glue_catalog_database" "dedup_process_glue_db" {
  name         = module.glue_db_naming.name
  location_uri = "s3://${var.project_objects.data_bucket.bucket_id}/"
  tags         = module.glue_db_naming.tags
}

#------------------------------------------------------------------------------
# Glue Security Configuration
#------------------------------------------------------------------------------

module "glue_secconfig_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "gls"
  purpose     = join("", [var.project_prefix, "-", "gluesecurityconfig"])
}

resource "aws_glue_security_configuration" "glue_security_config" {
  name = module.glue_secconfig_naming.name
  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = var.project_objects.glue_enc_key.key_arn
    }
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = var.project_objects.glue_enc_key.key_arn
    }
    s3_encryption {
      s3_encryption_mode = "SSE-S3"
    }
  }
}

#------------------------------------------------------------------------------
# Redshift Credentials
#------------------------------------------------------------------------------

data "aws_ssm_parameter" "redshift_conn_username" {
  name = "/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift/username"
}

data "aws_ssm_parameter" "redshift_conn_password" {
  name = "/secure/${var.site}/${var.environment}/${var.project_app_group}/redshift/password"
}

data "aws_ssm_parameter" "redshift_conn_jdbc_url" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/jdbc_url"
}

data "aws_ssm_parameter" "redshift_conn_subnetid" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/subnetid"
}

data "aws_ssm_parameter" "redshift_conn_securitygroupid" {
  name = "/parameter/${var.site}/${var.environment}/${var.project_app_group}/redshift/securitygroupid"
}

#------------------------------------------------------------------------------
# Glue Connection
#------------------------------------------------------------------------------

data "aws_subnet" "connection_subnet" {
  id = data.aws_ssm_parameter.redshift_conn_subnetid.value
}

module "glue_ingest_conn_naming" {
  source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
  base_object = var.base_naming
  type        = "glx"
  purpose     = join("", [var.project_prefix, "-", "ingestjobconnection"])
}

resource "aws_glue_connection" "redshift_connection" {
  connection_type = "JDBC"
  name            = module.glue_ingest_conn_naming.name
  tags            = module.glue_ingest_conn_naming.tags
  connection_properties = {
    JDBC_CONNECTION_URL = data.aws_ssm_parameter.redshift_conn_jdbc_url.value
    PASSWORD            = data.aws_ssm_parameter.redshift_conn_password.value
    USERNAME            = data.aws_ssm_parameter.redshift_conn_username.value
  }
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.connection_subnet.availability_zone
    subnet_id              = data.aws_subnet.connection_subnet.id
    security_group_id_list = [data.aws_ssm_parameter.redshift_conn_securitygroupid.value]
  }
}

#------------------------------------------------------------------------------
# Glue Ingest Job
#------------------------------------------------------------------------------

module "ingest_job" {
  source              = "../../../modules/glue"
  base_naming         = var.base_naming
  project_prefix      = var.project_prefix
  purpose             = "ingestjob"
  max_concurrent_runs = 4
  timeout             = 60
  worker_type         = "G.1X"
  number_of_workers   = 4
  retry_max_attempts  = 0
  retry_interval      = 2
  retry_backoff_rate  = 2
  security_config_id  = aws_glue_security_configuration.glue_security_config.id
  connections         = [aws_glue_connection.redshift_connection.name]
  glue_path = "../src/mainprocess/glue/job_policies"
  policy_variables = {"data_bucket_arn": var.project_objects.data_bucket.bucket_arn
                      "glue_bucket_arn": var.project_objects.glue_bucket.bucket_arn}
  
  script_location     = "s3://${var.project_objects.glue_bucket.bucket_id}/${aws_s3_object.glue_scripts["ingest_job.py"].id}"
  job_conf            = "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"
  extra_jars = join(",", ["s3://${var.project_objects.glue_bucket.bucket_id}/${aws_s3_object.glue_jars["delta-core_2.12-2.3.0.jar"].id}",
  "s3://${var.project_objects.glue_bucket.bucket_id}/${aws_s3_object.glue_jars["delta-storage-2.3.0.jar"].id}"])
  extra_py_files = "s3://${var.project_objects.glue_bucket.bucket_id}/${aws_s3_object.glue_jars["delta-core_2.12-2.3.0.jar"].id}"
}

# #------------------------------------------------------------------------------
# # Glue Crawler for Staging
# #------------------------------------------------------------------------------

# module "staging_crawler_role_naming" {
#   source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
#   base_object = module.base_naming
#   type        = "iro"
#   purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
# }
# resource "aws_iam_role" "staging_crawler_role" {
#   name = module.staging_crawler_role_naming.name
#   tags = module.staging_crawler_role_naming.tags
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = ["sts:AssumeRole"]
#         Effect = "Allow"
#         Sid    = "GlueAssumeRole"
#         Principal = {
#           Service = "glue.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# module "staging_crawler_naming" {
#   source      = "git::ssh://git@github.com/BrightMLS/common_modules_terraform.git//bright_naming_conventions?ref=v0.0.4"
#   base_object = module.base_naming
#   type        = "glr"
#   purpose     = join("", [var.project_prefix, "-", "staginggluecrawler"])
# }
# resource "aws_glue_crawler" "staging_crawler" {
#   database_name = aws_glue_catalog_database.dedup_process_glue_db.name
#   name          = module.staging_crawler_naming.name
#   tags          = module.staging_crawler_naming.tags
#   role          = aws_iam_role.staging_crawler_role.arn

#   delta_target {
#     write_manifest            = false
#     create_native_delta_table = true
#     delta_tables = [
#       "s3://${var.project_objects.data_bucket.bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_office_target_table_name}/",
#       "s3://${var.project_objects.data_bucket.bucket_id}/staging_data/${aws_glue_catalog_database.dedup_process_glue_db.name}/${var.lambda_ec_agent_target_table_name}/"
#     ]
#   }
# }
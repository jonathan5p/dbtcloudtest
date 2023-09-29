output "functions_mapping" {
  value = {
    "ingestjob" : module.ingest_job
    "cleaningjob" : module.cleaning_job
    "inddedupjob" : module.ind_dedup_job
    "orgdedupjob" : module.org_dedup_job
    "staging_crawler" : aws_glue_crawler.staging_crawler
    "gluedb_name" : aws_glue_catalog_database.dedup_process_glue_db.name
  }
}

output "aurora_conn_sg_id" {
  value = resource.aws_security_group.conn_sg.id
}
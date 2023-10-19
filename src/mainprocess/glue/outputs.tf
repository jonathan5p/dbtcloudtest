output "functions_mapping" {
  value = {
    "ingestjob" : module.ingest_job
    "cleaningjob" : module.cleaning_job
    "inddedupjob" : module.ind_dedup_job
    "orgdedupjob" : module.org_dedup_job
    "geojob" : module.geo_job
    "gluedb_name" : aws_glue_catalog_database.dedup_process_glue_db.name
  }
}

output "glue_conn_sg_id" {
  value = aws_security_group.conn_sg.id
}

output "alayasyncdb_path" {
  value = aws_glue_catalog_database.alayasync_process_glue_db.location_uri
}

output "alayasync_db" {
  value = aws_glue_catalog_database.alayasync_process_glue_db.name
}
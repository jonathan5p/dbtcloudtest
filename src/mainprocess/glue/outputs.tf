output "functions_mapping" {
    value = {
       "ingestjob": module.ingest_job
       "gluedb_name": aws_glue_catalog_database.dedup_process_glue_db.name
    }
}
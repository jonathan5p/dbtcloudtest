locals {
  json_data = jsondecode(file("${path.module}/${var.table_name}.json"))
}


resource "aws_glue_catalog_table" "table_succeeded" {
  name          = "${var.table_name}_succeeded"
  database_name = var.project_objects.alayasyncdb

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  partition_keys {
    name = local.json_data.first_partition_key.name
    type = local.json_data.first_partition_key.type
  }

  partition_keys {
    name = local.json_data.second_partition_key.name
    type = local.json_data.second_partition_key.type
  }

  storage_descriptor {
    location      = "${var.project_objects.alayasyncdb_path}/${var.table_name}_succeeded"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
  
    ser_de_info {
      name                  = "base-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
        name = local.json_data.primary_key.name
        type = local.json_data.primary_key.type
    }

  }
}


resource "aws_glue_catalog_table" "table_failed" {
  name          = "${var.table_name}_failed"
  database_name = var.project_objects.alayasyncdb

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  partition_keys {
    name = local.json_data.first_partition_key.name
    type = local.json_data.first_partition_key.type
  }

  partition_keys {
    name = local.json_data.second_partition_key.name
    type = local.json_data.second_partition_key.type
  }

  storage_descriptor {
    location      = "${var.project_objects.alayasyncdb_path}/${var.table_name}_failed"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
  
    ser_de_info {
      name                  = "base-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
        name = local.json_data.primary_key.name
        type = local.json_data.primary_key.type
    }

    columns {
      name = "status"
      type = "string"
    }

  }
}

resource "aws_glue_catalog_table" "table_results" {
  name          = "${var.table_name}_results"
  database_name = var.project_objects.alayasyncdb

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location      = "${var.project_objects.alayasyncdb_path}/${var.table_name}_results"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
  
    ser_de_info {
      name                  = "base-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
      name = "id"
      type = "string"
    }
    
    columns {
      name = "task_id"
      type = "string"
    }

    columns {
      name = "succeeded"
      type = "bigint"
    }

    columns {
      name = "failed"
      type = "bigint"
    }

  }
}

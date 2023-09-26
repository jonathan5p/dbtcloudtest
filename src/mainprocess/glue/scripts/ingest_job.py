import sys
import json
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from delta import DeltaTable


def unique_by_merge_key(input_df:DataFrame, merge_key:str, precombine_keys:list):
    unique_per_id = input_df.orderBy([merge_key,*precombine_keys], ascending=False).dropDuplicates([merge_key])
    return unique_per_id

def full_load(
        input_df:DataFrame, 
        target_path:str, 
        compression:str="snappy",
        catalog_db:str="default",
        catalog_table:str="test_table",
        partitions:str="",
        test:bool=False
        ):
    
    current_ts = F.current_timestamp()

    # Delta lake Id generation
    id_df = input_df.withColumn("dlid", F.expr("uuid()"))\
                    .withColumn("dlingestionts", current_ts)\
                    .withColumn("dllastmodificationts", current_ts)


    if partitions not in ["", None]:
        write_df = id_df.write.mode("overwrite")\
                              .format("delta")\
                              .option("path", target_path)\
                              .partitionBy(partitions.split(","))\
                              .option("compression", compression)\
                              .option("overwriteSchema", "true")
    else:
        write_df = id_df.write.mode("overwrite")\
                              .format("delta")\
                              .option("path", target_path)\
                              .option("overwriteSchema", "true")\
                              .option("compression", compression)
    
    if test:
        write_df.save()
    else:
        write_df.saveAsTable(f"{catalog_db}.{catalog_table}")

def incremental_load(
        spark:SparkSession,
        input_df:DataFrame,
        target_path:str,
        merge_key:str,
        update_condition:str
        ):

    input_df.createOrReplaceTempView("changes_df")
    target_df = DeltaTable.forPath(spark,target_path)
    target_df.toDF().createOrReplaceTempView("target_df")

    changes_df = spark.sql(f"select changes_df.*, target_df.dlid, target_df.dlingestionts, target_df.dllastmodificationts from changes_df left join target_df on changes_df.{merge_key}=target_df.{merge_key}")
    
    current_ts = F.current_timestamp()
    changes_with_gid = changes_df.withColumn("dlingestionts", F.when(F.col("dlid").isNull(),
                                            current_ts).otherwise(F.col("dlingestionts")))\
                                .withColumn("dlid", F.when(F.col("dlid").isNull(),
                                            F.expr("uuid()")).otherwise(F.col("dlid")))\
                                .withColumn("dllastmodificationts", current_ts)

    target_df.alias("target")\
        .merge(changes_with_gid.alias("source"),f"target.{merge_key} = source.{merge_key}") \
        .whenMatchedUpdateAll(condition = update_condition)\
        .whenNotMatchedInsertAll()\
        .whenNotMatchedBySourceDelete()\
        .execute()

if __name__ == "__main__":
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "target",
            "target_prefixes",
            "catalog_table",
            "catalog_database",
            "options",
            "connection_type"
        ],
    )

    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(f"{args['JOB_NAME']}-{args['catalog_database']}-{args['catalog_table']}", args)

    write_options = json.loads(args["options"]).get("write_options",{})
    conn_ops = json.loads(args["options"]).get("connection_options",{})
    merge_key=write_options.get("merge_key")
    s3_target_path = f"s3://{args.get('target')}/{args.get('target_prefixes')}/{args.get('catalog_database')}/{args.get('catalog_table')}/"

    input_df = glueContext.create_dynamic_frame_from_options(
        connection_type=args.get("connection_type"),
        connection_options=conn_ops,
        transformation_ctx=f"{args['catalog_database']}-{args['catalog_table']}",
    ).toDF()

    precombine_keys=write_options.get("precombine_keys","").split(",")
    unique_per_id = unique_by_merge_key(input_df,merge_key,precombine_keys)

    write_mode = write_options.get("write_mode", "full")
    partitions = write_options.get("partitions")

    if write_mode == "full":
        
        full_load(unique_per_id,
                  s3_target_path,
                  write_options.get("compression"),
                  args['catalog_database'],
                  args['catalog_table'],
                  partitions=partitions
                )

    elif write_mode == "incremental":

        if spark._jsparkSession.catalog().tableExists(args['catalog_database'], args['catalog_table']):
            
            incremental_load(
                spark,
                unique_per_id,
                s3_target_path,
                merge_key,
                write_options.get("update_condition")
            )

        else: 
            raise ValueError("Table doesn't exist or Glue data Catalog is not connected. Please run a full load and verify the connection to the Glue data Catalog.")

    else:
        raise ValueError(f"Incorrect write mode, expected values are [full,incremental], got: {write_mode}")

    job.commit()
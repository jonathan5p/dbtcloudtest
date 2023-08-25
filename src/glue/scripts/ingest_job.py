import sys
import json
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from delta import DeltaTable

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

read_options = json.loads(args["options"]).get("read_options")
write_options = json.loads(args["options"]).get("write_options")
conn_ops = json.loads(args["options"]).get("connection_options")
merge_key=write_options.get("merge_key")
s3_target_path = f"s3://{args.get('target')}/{args.get('target_prefixes')}/{args.get('catalog_database')}/{args.get('catalog_table')}/"

input_df = glueContext.create_dynamic_frame_from_options(
    connection_type=args.get("connection_type"),
    format=read_options.get("read_format"),
    connection_options=conn_ops,
    format_options=read_options,
    transformation_ctx=f"{args['catalog_database']}-{args['catalog_table']}",
).toDF()

precombine_keys=write_options.get("precombine_keys","").split(",")
unique_per_id = input_df.orderBy([merge_key,*precombine_keys], ascending=False).dropDuplicates([merge_key])

write_mode = write_options.get("write_mode", "full")
partitions = write_options.get("partitions")

if write_mode == "full":
    # Delta lake Id generation

    current_ts = F.current_timestamp()

    id_df = unique_per_id.withColumn("dlid", F.expr("uuid()"))\
                         .withColumn("dlingestionts", current_ts)\
                         .withColumn("dllastmodificationts", current_ts)


    if partitions not in ["", None]:
        id_df.write.mode("overwrite")\
                    .format("delta")\
                    .option("path", s3_target_path)\
                    .partitionBy(write_options.get("partitions").split(","))\
                    .option("compression", write_options.get("compression"))\
                    .option("overwriteSchema", "true")\
                    .saveAsTable(f"{args['catalog_database']}.{args['catalog_table']}")
    else:  
        id_df.write.mode("overwrite")\
                    .format("delta")\
                    .option("path", s3_target_path)\
                    .option("overwriteSchema", "true")\
                    .option("compression", write_options.get("compression"))\
                    .saveAsTable(f"{args['catalog_database']}.{args['catalog_table']}")
elif write_mode == "incremental":

    if spark._jsparkSession.catalog().tableExists(args['catalog_database'], args['catalog_table']):

        unique_per_id.createOrReplaceTempView("changes_df")
        target_df = DeltaTable.forPath(spark,s3_target_path)
        target_df.toDF().createOrReplaceTempView("target_df")

        changes_df = spark.sql(f"select changes_df.*, target_df.dlid, target_df.dlingestionts, target_df.dllastmodificationts from changes_df left join target_df on changes_df.{merge_key}=target_df.{merge_key}")
        
        current_ts = F.current_timestamp()
        changes_with_gid = changes_df.withColumn("dlingestionts", F.when(F.col("dlid").isNull(),
                                                current_ts).otherwise(F.col("dlingestionts")))\
                                     .withColumn("dlid", F.when(F.col("dlid").isNull(),
                                                F.expr("uuid()")).otherwise(F.col("dlid")))\
                                     .withColumn("dllastmodificationts", current_ts)
        
        changes_with_gid.show(5)

        target_df.alias("target")\
            .merge(changes_with_gid.alias("source"),f"target.{merge_key} = source.{merge_key}") \
            .whenMatchedUpdateAll(condition = write_options.get("update_condition"))\
            .whenNotMatchedInsertAll()\
            .whenNotMatchedBySourceDelete()\
            .execute()
    else: 
        raise Exception("Table doesn't exist or Glue data Catalog is not connected. Please run a full load and verify the connection to the Glue data Catalog.")

job.commit()
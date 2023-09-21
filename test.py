from pyspark import SparkContext, SparkConf
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from awsglue.context import GlueContext
from awsglue.job import Job
import pyspark.pandas as ps
from awsglue.utils import getResolvedOptions
from pyspark.sql.types import BooleanType
import sys

sys.argv.append("--JOB_NAME")
sys.argv.append("unit_testing")
sys.argv.append("--datalake-formats")
sys.argv.append("delta")

args = getResolvedOptions(sys.argv, ["JOB_NAME"])

conf = SparkConf()
sc = SparkContext.getOrCreate(conf=conf)
context = GlueContext(sc)
job = Job(context)
job.init(args["JOB_NAME"], args)
spark = context.spark_session

df = spark.read.parquet(
    "/home/glue_user/workspace/tests/sample_data/consume_data/organizations/"
)

df1 = df.limit(10)

windowSpec = Window.orderBy(
    F.col("orgglobalidentifier").desc()
)  # Order by a constant to get a stable order
df_with_seq_id = df1.withColumn("sequential_id", F.row_number().over(windowSpec))

df1 = df_with_seq_id.withColumn(
    "orgglobalidentifier",
    F.concat(F.lit("ORG"), F.lpad(F.col("sequential_id"), 8, "0")),
).drop("sequential_id")
df1.createOrReplaceTempView("target_df")

df2 = df.limit(20).drop("orgglobalidentifier")
df2.createOrReplaceTempView("changes_df")

merge_key = "bdmporgkey"

sql_query = f"select changes_df.*, target_df.orgglobalidentifier from changes_df left join target_df on changes_df.{merge_key}=target_df.{merge_key}"   

tmp_df = spark.sql(sql_query)
df3 = tmp_df.withColumn(
    "orgglobalidentifier",
    F.when(
        F.col("orgglobalidentifier").isNull(),
        F.concat(F.lit("ORG"), F.lpad(F.row_number().over(windowSpec), 8, "0")),
    ).otherwise(F.col("orgglobalidentifier")),
)

#print(df3.select("orghubid",merge_key,"orgglobalidentifier").show())

county_info = ps.read_csv("/home/glue_user/workspace/tests/sample_data/raw_data/county_info/RulesToDetermineNativeRecords.csv")
bright_participants = county_info.groupby("Bright Participant/Bordering").get_group("Bright Participant")
county_list = bright_participants[["Upper County","State"]].values.tolist() + bright_participants[["County Name","State"]].values.tolist()

check_pairs = F.udf(lambda pair: True if pair in county_list else False, BooleanType())

df4 = df3.withColumn("bright_participant", check_pairs(F.array(F.col("orgcounty"),F.col("orgstate")))).drop("orglinkedglobalidentifier")
dup_df = df4.withColumn("orgglobalidentifier",F.lit("ORGTEST"))
df4 = df4.union(dup_df)
df4.createOrReplaceTempView("df4")

sql_query = f"""
WITH native_records AS(
    SELECT 
        orghubid, 
        bright_participant,
        orgglobalidentifier 
    FROM (  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY orghubid ORDER BY orgglobalidentifier ASC) AS row_num
  FROM df4
  WHERE bright_participant)
    WHERE row_num = 1
)
SELECT df4.*,
       CASE WHEN 
       native_records.orgglobalidentifier = df4.orgglobalidentifier
       THEN  ' '
       ELSE COALESCE(native_records.orgglobalidentifier, '') END as orglinkedglobalidentifier
FROM df4 
LEFT JOIN native_records ON df4.orghubid = native_records.orghubid
ORDER BY df4.{merge_key} DESC
"""

print(df4.select("orghubid").groupBy("orghubid").count().show())
print(df4.count())
print(df4.select(F.countDistinct("orghubid")).show())
print(df4.select("orghubid",merge_key,"orgglobalidentifier", "orgcounty","orgstate","bright_participant").show(40))



df5 = spark.sql(sql_query)

df5.withColumn("testcol",F.lit(None))

# print(df5.select("orghubid",merge_key,"orgglobalidentifier","orglinkedglobalidentifier","bright_participant").show())
# print(df5.count())

df6 = spark.sql(f"""
    SELECT 
        orghubid, 
        bright_participant,
        orgglobalidentifier,
        row_num 
    FROM (  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY orghubid ORDER BY orgglobalidentifier DESC) AS row_num
  FROM df4
  WHERE bright_participant);
""")

# print(df6.show())
job.commit()

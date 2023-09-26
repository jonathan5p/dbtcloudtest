import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.types import BooleanType
import pyspark.sql.functions as F
from pyspark.sql.window import Window
from awsglue.context import GlueContext
from awsglue.job import Job
from splink.spark.linker import SparkLinker
import pyspark.pandas as ps
import boto3
import json

# Generate individuals table query
sql_map_query = """ 
SELECT 
    ind_clusters_df.dlid as bdmpindkey,
    ind_clusters_df.mlsid as indsourcerecordid,
    ind_clusters_df.key as indsourcerecordkey,
    ind_clusters_df.officekey as indorgid,
    ind_clusters_df.officemlsid as indorgsourcerecordid,
    ind_clusters_df.cluster_id as indhubid,
    ind_clusters_df.firstname as indfirstname,
    ind_clusters_df.lastname||' '||ind_clusters_df.namesuffix  as indlastname,
    ind_clusters_df.middleinitial as indmiddleinitial,
    ind_clusters_df.fullname as indfullname,
    ind_clusters_df.preferredfirstname||' '||ind_clusters_df.preferredlastname as indalternatename,
    upper(ind_clusters_df.address) as indstreetaddress,
    upper(ind_clusters_df.city) as indaddresscity,
    ind_clusters_df.stateorprovince as indaddressstate,
    ind_clusters_df.postalcode as indaddresspostalcode,
    office_df.officecounty as indaddresscounty,
    CASE WHEN ind_clusters_df.country = 'US' 
    THEN 'USA' 
    ELSE upper(ind_clusters_df.country) END as indaddresscountry,
    ind_clusters_df.email as indpublicemail,
    ind_clusters_df.privateemail as indprivateemail,
    ind_clusters_df.socialmediawebsiteurlorid as indurl,
    ind_clusters_df.preferredphone as indprimaryphone,
    ind_clusters_df.preferredphoneext as indprimaryphoneext,
    ind_clusters_df.directphone as indsecondaryphone,
    ind_clusters_df.mobilephone as indmobilephone,
    ind_clusters_df.officephone as indofficephone,
    ind_clusters_df.officephoneext as indofficephoneext,
    ind_clusters_df.nationalassociationid as indnrdsid,
    ind_clusters_df.type||' '||ind_clusters_df.subtype as indtype,
    ind_clusters_df.status as indstatus,
    ind_clusters_df.joindate as indjoindate,
    ind_clusters_df.terminationdate as indterminateddate,
    ind_clusters_df.dateadded as sourcesystemcreatedtms,
    ind_clusters_df.modificationtimestamp as sourcesystemmodtms,
    'OIDH' as indsourcetransport,
    ind_clusters_df.subsystemlocale as indsourcename,
    ind_clusters_df.uniqueorgid as indsourceresouoi,
    '' as indexpirationdate,
    ind_clusters_df.dlingestionts as indcreatedts,
    current_timestamp() as indlastmodifiedts
FROM ind_clusters_df
LEFT JOIN office_df ON ind_clusters_df.officemlsid = office_df.officemlsid
"""

# Query that gets native records for each cluster
# and linked global identifiers for each record
native_records_query = """
WITH native_records AS(
    SELECT 
        indhubid, 
        indisbrightparticipant,
        indglobalidentifier 
    FROM (  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY indhubid ORDER BY indglobalidentifier ASC) AS row_num
  FROM ind_bright_participants
  WHERE indisbrightparticipant)
    WHERE row_num = 1
)
SELECT ind_bright_participants.*,
       CASE WHEN 
       native_records.indglobalidentifier = ind_bright_participants.indglobalidentifier OR ind_bright_participants.indhubid IS NULL
       THEN  ' '
       ELSE COALESCE(native_records.indglobalidentifier, '') END as indlinkedglobalidentifier
FROM ind_bright_participants 
LEFT JOIN native_records ON ind_bright_participants.indhubid = native_records.indhubid
ORDER BY ind_bright_participants.indhubid DESC
"""

# Define merge_key var as primary key of the individuals table
merge_key = "bdmpindkey"

# Native record agent valid types for deduping
agent_types = [
    "Broker",
    "Office Manager",
    "Appraiser",
    "Personal Assistant",
    "Staff",
    "Agent",
]


# Helper function to run splink model over a dataframe
def deduplicate_entity(
    entity: str,
    spark: SparkSession,
    spark_df: DataFrame,
    splink_model_path: str,
    splink_config: dict = None,
):
    if splink_config == None:
        s3.download_file(
            args["config_bucket"],
            f'{entity}/version_{args["model_version"]}/splink_model.json',
            f"/tmp/{entity}_splink_model.json",
        )
        s3.download_file(
            args["config_bucket"],
            f'{entity}/version_{args["model_version"]}/splink_config.json',
            f"/tmp/{entity}_splink_config.json",
        )

        splink_config = json.load(open(f"/tmp/{entity}_splink_config.json"))

    print(f"{entity} splink config: ", splink_config)

    linker = SparkLinker(spark_df, spark=spark, break_lineage_method="parquet")
    linker.load_model(splink_model_path)

    predictions = linker.predict(threshold_match_probability=0.2)
    clusters = linker.cluster_pairwise_predictions_at_threshold(
        predictions,
        threshold_match_probability=splink_config["THRESHOLD_MATCH_PROBABILITY"],
    )

    clusters_df = ps.from_pandas(clusters.as_pandas_dataframe()).to_spark()

    return clusters_df


def generate_globalids_and_native_records(
    source_df: DataFrame, county_list: list, order_key: str = "indhubid"
):
    null_global_ids_df = source_df.where(source_df["indglobalidentifier"].isNull())
    not_null_count = source_df.where(
        source_df["indglobalidentifier"].isNotNull()
    ).count()

    windowSpec = Window.orderBy(F.col(order_key).desc())

    filled_global_ids_df = null_global_ids_df.withColumn(
        "new_indglobalidentifier",
        F.concat(
            F.lit("IND"),
            F.lpad(F.row_number().over(windowSpec) + not_null_count, 8, "0"),
        ),
    )

    global_id_df = (
        source_df.join(
            filled_global_ids_df,
            source_df["bdmpindkey"] == filled_global_ids_df["bdmpindkey"],
            how="leftouter",
        )
        .select(source_df["*"], filled_global_ids_df["new_indglobalidentifier"])
        .withColumn(
            "indglobalidentifier",
            F.when(
                source_df["indglobalidentifier"].isNotNull(),
                source_df["indglobalidentifier"],
            ).otherwise(filled_global_ids_df["new_indglobalidentifier"]),
        )
        .drop("new_indglobalidentifier")
    )

    check_pairs = F.udf(
        lambda pair: True if pair in county_list else False, BooleanType()
    )

    bright_participants_df = global_id_df.withColumn(
        "indisbrightparticipant",
        check_pairs(F.array(F.col("indaddresscounty"), F.col("indaddressstate"))),
    )
    bright_participants_df.createOrReplaceTempView("ind_bright_participants")

    individuals_df = spark.sql(native_records_query)
    return individuals_df


if __name__ == "__main__":
    params = [
        "JOB_NAME",
        "TempDir",
        "config_bucket",
        "model_version",
        "data_bucket",
        "glue_db",
        "agent_table_name",
        "office_table_name",
        "ssm_params_base",
        "aurora_table",
        "county_info_s3_path",
        "max_records_per_file",
    ]
    args = getResolvedOptions(sys.argv, params)

    s3 = boto3.client("s3")
    ssm = boto3.client("ssm")

    sc = SparkContext()
    sc.setCheckpointDir(args["TempDir"])
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    # Read clean agent data and enrich office data
    splink_clean_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['agent_table_name']}/"
    clean_df = spark.read.format("parquet").load(splink_clean_data_s3_path)

    office_data_s3_path = f"s3://{args['data_bucket']}/staging_data/{args['glue_db']}/{args['office_table_name']}/"
    office_df = spark.read.format("delta").load(office_data_s3_path)
    office_df.createOrReplaceTempView("office_df")

    # Filter agents
    dedup_records = clean_df.where(F.col("type").isin(agent_types))

    # Run splink model over office and team data
    dedup_agent_df = deduplicate_entity(
        entity="agent",
        spark_df=dedup_records,
        spark=spark,
        splink_model_path="/tmp/agent_splink_model.json",
    )

    clusters_df = clean_df.join(
        dedup_agent_df, clean_df["dlid"] == dedup_agent_df["dlid"], how="leftouter"
    ).select(
        clean_df["*"], dedup_agent_df["cluster_id"], dedup_agent_df["tf_postalcode"]
    )
    clusters_df.createOrReplaceTempView("ind_clusters_df")

    # Get Aurora DB credentials
    username = ssm.get_parameter(
        Name=f"/secure/{args['ssm_params_base']}/username", WithDecryption=True
    )["Parameter"]["Value"]
    jdbcurl = ssm.get_parameter(Name=f"/parameter/{args['ssm_params_base']}/jdbc_url")[
        "Parameter"
    ]["Value"]
    password = ssm.get_parameter(
        Name=f"/secure/{args['ssm_params_base']}/password", WithDecryption=True
    )["Parameter"]["Value"]

    # Generate new individuals table
    individuals_changes_df = spark.sql(sql_map_query)

    # Get current Individuals table from Aurora
    try:
        cur_ind_df = (
            spark.read.format("jdbc")
            .option("url", jdbcurl)
            .option("user", username)
            .option("password", password)
            .option("dbtable", args["aurora_table"])
            .load()
        )
        cur_ind_df.createOrReplaceTempView("target_df")
        individuals_changes_df.createOrReplaceTempView("changes_df")

        join_query = f"select changes_df.*, target_df.indglobalidentifier from changes_df left join target_df on changes_df.{merge_key}=target_df.{merge_key}"
        ind_changes_df = spark.sql(join_query)

    except Exception as e:
        if 'relation "{table}" does not exist'.format(
            table=args["aurora_table"]
        ) in str(e):
            ind_changes_df = individuals_changes_df.withColumn(
                "indglobalidentifier", F.lit(None)
            )
        else:
            print("Aurora Exception: ", str(e))
            raise e

    # # Retrieve native record county rules from s3
    # # and generate a county list with all the counties that are Bright Participants
    county_df = ps.read_csv(args["county_info_s3_path"])

    bright_participants = county_df.groupby("Bright Participant/Bordering").get_group(
        "Bright Participant"
    )
    county_list = (
        bright_participants[["Upper County", "State"]].values.tolist()
        + bright_participants[["County Name", "State"]].values.tolist()
    )

    # # Generate global ids and final individuals df
    individuals_df = generate_globalids_and_native_records(ind_changes_df, county_list)

    # Write data to S3
    clusters_df.write.mode("overwrite").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/splink_agent_cluster_df/",
    ).option("overwriteSchema", "true").option("compression", "snappy").saveAsTable(
        f"{args['glue_db']}.splink_agent_cluster_df"
    )

    individuals_df.withColumn(
        "dt_utc",
        F.date_format(
            F.date_trunc("second", F.current_timestamp()), "yyyy-MM-dd-HH-mm-ss"
        ).cast("string"),
    ).write.mode("append").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/individuals/",
    ).option(
        "overwriteSchema", "true"
    ).option(
        "maxRecordsPerFile", args.get("max_records_per_file", 1000)
    ).option(
        "compression", "snappy"
    ).partitionBy(
        "dt_utc"
    ).saveAsTable(
        f"{args['glue_db']}.individuals"
    )

    spark.sql(f"MSCK REPAIR TABLE {args['glue_db']}.individuals DROP PARTITIONS;")

    # Write data to the Aurora PostgreSQL database

    individuals_df.write.format("jdbc").mode("overwrite").option("url", jdbcurl).option(
        "user", username
    ).option("password", password).option("dbtable", args["aurora_table"]).save()

    job.commit()

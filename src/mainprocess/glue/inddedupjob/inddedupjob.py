import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import DataFrame, SparkSession
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.types import BooleanType
import pyspark.sql.functions as F
from pyspark.sql.window import Window
from awsglue.context import GlueContext
from awsglue.job import Job
from splink.spark.linker import SparkLinker
import pyspark.pandas as ps
from datetime import datetime
import boto3
import json

# Generate individuals table query
sql_map_query = """ 
SELECT 
    cs.dlid as bdmpindkey,
    cs.mlsid as indsourcerecordid,
    cs.key as indsourcerecordkey,
    cs.officekey as indorgid,
    cs.officemlsid as indorgsourcerecordid,
    cs.cluster_id as indhubid,
    cs.firstname as indfirstname,
    cs.lastname||' '||cs.namesuffix  as indlastname,
    cs.middleinitial as indmiddleinitial,
    cs.fullname as indfullname,
    cs.preferredfirstname||' '||cs.preferredlastname as indalternatename,
    upper(cs.address) as indstreetaddress,
    upper(cs.city) as indaddresscity,
    cs.stateorprovince as indaddressstate,
    cs.postalcode as indaddresspostalcode,
    odf.officecounty as indaddresscounty,
    CASE WHEN cs.country = 'US' 
    THEN 'USA' 
    ELSE upper(cs.country) END as indaddresscountry,
    cs.email as indpublicemail,
    cs.privateemail as indprivateemail,
    cs.socialmediawebsiteurlorid as indurl,
    cs.preferredphone as indprimaryphone,
    cs.preferredphoneext as indprimaryphoneext,
    cs.directphone as indsecondaryphone,
    cs.mobilephone as indmobilephone,
    cs.officephone as indofficephone,
    cs.officephoneext as indofficephoneext,
    cs.nationalassociationid as indnrdsid,
    cs.type||' '||cs.subtype as indtype,
    cs.status as indstatus,
    cs.joindate as indjoindate,
    cs.terminationdate as indterminateddate,
    cs.dateadded as sourcesystemcreatedtms,
    cs.modificationtimestamp as sourcesystemmodtms,
    'OIDH' as indsourcetransport,
    CASE WHEN cs.subsystemlocale = 'BRIGHT_CAAR'
    THEN 'CAAR'
    ELSE 'BrightMls' END as indsourcename,
    cs.uniqueorgid as indsourceresouoi,
    '' as indexpirationdate,
    cs.dlingestionts as indcreatedts,
    current_timestamp() as indlastmodifiedts
FROM ind_clusters_df as cs
LEFT JOIN office_df as odf ON cs.officemlsid = odf.officemlsid
"""

# Query that gets native records for each cluster
# and linked global identifiers for each record
native_records_query = """
WITH native_records AS(
	SELECT indhubid,
		indcanbenative,
		indglobalidentifier
	FROM (
			SELECT *,
				ROW_NUMBER() OVER (
					PARTITION BY indhubid
					ORDER BY indglobalidentifier ASC, indstatus ASC
				) AS row_num
			FROM ind_bright_participants
			WHERE indcanbenative
		)
	WHERE row_num = 1
)
SELECT ibp.*,
	CASE
		WHEN nr.indglobalidentifier = ibp.indglobalidentifier
		OR ibp.indhubid IS NULL THEN ' ' ELSE COALESCE(nr.indglobalidentifier, '')
	END as indlinkedglobalidentifier
FROM ind_bright_participants as ibp
	LEFT JOIN native_records as nr ON ibp.indhubid = nr.indhubid
ORDER BY ibp.indhubid DESC
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
        "indcanbenative",
        check_pairs(F.array(F.col("indaddresscounty"), F.col("indaddressstate"))),
    )
    bright_participants_df.createOrReplaceTempView("ind_bright_participants")

    output_df = spark.sql(native_records_query)
    return output_df


if __name__ == "__main__":
    params = [
        "JOB_NAME",
        "TempDir",
        "config_bucket",
        "model_version",
        "data_bucket",
        "glue_db",
        "alaya_glue_db",
        "agent_table_name",
        "office_table_name",
        "ssm_params_base",
        "aurora_table",
        "county_info_s3_path",
        "max_records_per_file",
        "aurora_connection_name",
        "alaya_trigger_key",
    ]
    args = getResolvedOptions(sys.argv, params)

    conn_ops = {
        "useConnectionProperties": "True",
        "dbtable": args["aurora_table"],
        "connectionName": args["aurora_connection_name"],
    }

    s3 = boto3.client("s3")

    sc = SparkContext()
    sc.setCheckpointDir(args["TempDir"])
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    # Read clean agent data and enrich office data
    splink_clean_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['agent_table_name']}/"
    clean_df = spark.read.format("delta").load(splink_clean_data_s3_path)

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

    # Generate new individuals table
    individuals_changes_df = spark.sql(sql_map_query)

    # Get current Individuals table from Aurora
    try:
        cur_ind_df = glueContext.create_dynamic_frame_from_options(
            connection_type="postgresql", connection_options=conn_ops
        ).toDF()

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

    bright_participants = county_df.groupby("Native/Bordering").get_group("Native")
    county_list = (
        bright_participants[["Upper County", "State"]].values.tolist()
        + bright_participants[["County Name", "State"]].values.tolist()
    )

    # # Generate global ids and final individuals df
    individuals_df = generate_globalids_and_native_records(ind_changes_df, county_list)

    # Write data to S3
    partition_col = "dt_utc"
    partition_value = str(datetime.now().strftime("%Y-%m-%d-%H-%M-%S"))

    clusters_df.withColumn(partition_col, F.lit(partition_value)).write.mode(
        "overwrite"
    ).format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/splink_agent_cluster/",
    ).option(
        "overwriteSchema", "true"
    ).option(
        "compression", "snappy"
    ).partitionBy(
        partition_col
    ).saveAsTable(
        f"{args['glue_db']}.splink_agent_cluster_df"
    )

    ind_writer = (
        individuals_df.withColumn(partition_col, F.lit(partition_value))
        .write.format("parquet")
        .option(
            "path",
            f"s3://{args['data_bucket']}/consume_data/{args['alaya_glue_db']}/individuals/",
        )
        .option("maxRecordsPerFile", int(args.get("max_records_per_file", 1000)))
        .option("compression", "snappy")
        .partitionBy(partition_col)
    )

    table_exists = spark.catalog._jcatalog.tableExists(
        f"{args['alaya_glue_db']}.individuals"
    )

    if table_exists:
        ind_writer.mode("append").save()
        spark.sql(
            f"MSCK REPAIR TABLE {args['alaya_glue_db']}.individuals DROP PARTITIONS;"
        )
    else:
        ind_writer.mode("overwrite").saveAsTable(f"{args['alaya_glue_db']}.individuals")

    # Write data to the Aurora PostgreSQL database

    glueContext.write_dynamic_frame.from_options(
        frame=DynamicFrame.fromDF(individuals_df, glueContext, "individuals"),
        connection_type="postgresql",
        connection_options=conn_ops,
    )

    # Trigger update alaya process
    update_alaya_payload = {
        "batch": partition_value,
        "table": "individuals",
        "database": args["alaya_glue_db"],
    }

    s3.put_object(
        Bucket=args["data_bucket"],
        Body=json.dumps(update_alaya_payload),
        Key=f"{args['alaya_trigger_key']}/individuals_{partition_value}.json",
    )

    job.commit()

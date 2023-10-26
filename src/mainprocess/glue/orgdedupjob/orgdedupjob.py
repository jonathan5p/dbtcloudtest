import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.window import Window
from pyspark.sql.types import BooleanType, NullType
import pyspark.sql.functions as F
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from pyspark.sql import DataFrame, SparkSession
from splink.spark.linker import SparkLinker
import pyspark.pandas as ps
from datetime import datetime
import boto3
import json

# Map teams to organizations structure query
team_sql_map_query = """ 
    SELECT 
        dtf.dlid as bdmporgkey,
        dof.uniqueorgid as orgsourceresouoi,
        string(dtf.cluster_id) as orghubid,
        CASE WHEN dtf.subsystemlocale = 'BRIGHT_CAAR'
        THEN 'CAAR'
        ELSE 'BrightMls'
        END as orgsourcename,
        dof.mlsid as orgsourcerecordid,
        string(dtf.key) as orgsourcerecordkey,
        string(dtf.dlingestionts) as orgcreatedts,
        string(current_timestamp()) as orglastmodifiedts,
        dof.orgsourcetype as orgsourcetype,
        dof.type||' '||dof.branchtype as orgtype,
        dof.status as orgstatus,
        dtf.name as orgname,
        upper(dof.address) as orgstreetaddress,
        upper(dof.city) as orgcity,
        dof.stateorprovince as orgstate,
        dof.postalcode as orgpostalcode,
        dof.county as orgcounty,
        CASE WHEN dof.country = 'US' 
        THEN 'USA' 
        ELSE upper(dof.country) END as orgcountry,
        dof.phone as orgprimaryphone,
        int(dof.phoneext) as orgprimaryphoneext,
        dof.phoneother as orgsecondaryphone,
        dof.fax as orgfax,
        dof.email as orgemail,
        dof.socialmediawebsiteurlorid as orgurl,
        dof.corporatelicense as orglicensenumber,
        string(dof.dateterminated) as orglicenseexpirationdate,
        dof.nationalassociationid as orgnrdsid,
        dof.mainname as orgparentorgname,
        dof.mainmlsid as orgparentorgsourcerecordid,
        string(dof.mainkey) as orgparentorgsourcerecordkey,
        dof.brokermlsid as orgindividualbrokerid,
        string(dof.brokerkey) as orgindividualbrokerkey,
        string(dof.dateadded) as orgstartdate,
        string(dof.dateterminated) as orgexpirationdate,
        'OIDH' as orgsourcetransport,
        dof.tradingas as orgtradingasname,
        string(dtf.key) as orgalternatesourcerecordkey,
        string(dof.dateadded) as sourcesystemcreatedtms,
        string(dtf.modificationtimestamp) as sourcesystemmodtms,
        false as orgcanbenative
    FROM dedup_team_df as dtf
    LEFT JOIN dedup_office_df as dof ON dtf.unique_id__office = dof.key
    """

# Map offices to organizations structure query
office_sql_map_query = """ 
    SELECT 
        dedup_office_df.dlid as bdmporgkey,
        dedup_office_df.uniqueorgid as orgsourceresouoi,
        string(dedup_office_df.cluster_id) as orghubid,
        CASE WHEN dedup_office_df.subsystemlocale = 'BRIGHT_CAAR'
        THEN 'CAAR'
        ELSE 'BrightMls'
        END as orgsourcename,
        dedup_office_df.mlsid as orgsourcerecordid,
        string(dedup_office_df.key) as orgsourcerecordkey,
        string(dedup_office_df.dlingestionts) as orgcreatedts,
        string(current_timestamp()) as orglastmodifiedts,
        dedup_office_df.orgsourcetype as orgsourcetype,
        dedup_office_df.type||' '||dedup_office_df.branchtype as orgtype,
        dedup_office_df.status as orgstatus,
        dedup_office_df.name as orgname,
        upper(dedup_office_df.address) as orgstreetaddress,
        upper(dedup_office_df.city) as orgcity,
        dedup_office_df.stateorprovince as orgstate,
        dedup_office_df.postalcode as orgpostalcode,
        dedup_office_df.county as orgcounty,
        CASE WHEN dedup_office_df.country = 'US' 
        THEN 'USA' 
        ELSE upper(dedup_office_df.country) END as orgcountry,
        dedup_office_df.phone as orgprimaryphone,
        int(dedup_office_df.phoneext) as orgprimaryphoneext,
        dedup_office_df.phoneother as orgsecondaryphone,
        dedup_office_df.fax as orgfax,
        dedup_office_df.email as orgemail,
        dedup_office_df.socialmediawebsiteurlorid as orgurl,
        dedup_office_df.corporatelicense as orglicensenumber,
        string(dedup_office_df.dateterminated) as orglicenseexpirationdate,
        dedup_office_df.nationalassociationid as orgnrdsid,
        dedup_office_df.mainname as orgparentorgname,
        dedup_office_df.mainmlsid as orgparentorgsourcerecordid,
        string(dedup_office_df.mainkey) as orgparentorgsourcerecordkey,
        dedup_office_df.brokermlsid as orgindividualbrokerid,
        string(dedup_office_df.brokerkey) as orgindividualbrokerkey,
        string(dedup_office_df.dateadded) as orgstartdate,
        string(dedup_office_df.dateterminated) as orgexpirationdate,
        'OIDH' as orgsourcetransport,
        dedup_office_df.tradingas as orgtradingasname,
        string(dedup_office_df.key) as orgalternatesourcerecordkey,
        string(dedup_office_df.dateadded) as sourcesystemcreatedtms,
        string(dedup_office_df.modificationtimestamp) as sourcesystemmodtms,
        canbenative as orgcanbenative
    FROM dedup_office_df
    """

# Query that gets native records for each cluster
# and linked global identifiers for each record
native_records_query = """
WITH native_records AS(
	SELECT orghubid,
		orgcanbenative,
		orgglobalidentifier
	FROM (
			SELECT *,
				ROW_NUMBER() OVER (
					PARTITION BY orghubid
					ORDER BY orgglobalidentifier ASC, orgstatus ASC
				) AS row_num
			FROM bright_participants_df
			WHERE orgcanbenative
		)
	WHERE row_num = 1
)
SELECT bdf.*,
	CASE
		WHEN native_records.orgglobalidentifier = bdf.orgglobalidentifier
		OR bdf.orghubid IS NULL THEN ' ' ELSE COALESCE(native_records.orgglobalidentifier, '')
	END as orglinkedglobalidentifier
FROM bright_participants_df as bdf
	LEFT JOIN native_records ON bdf.orghubid = native_records.orghubid
ORDER BY bdf.orghubid DESC
"""

# Define merge_key var as primary key of the organizations table
merge_key = "orgsourcerecordkey"

# Native record office valid types for deduping
office_types = [
    "APPRAISER",
    "RESIDENTIAL",
    "ASSOCIATION",
    "COMMERCIAL",
    "MLS",
    "PROPERTY MANAGEMENT",
    "CORPORATE",
]


def generate_canbenative_col(source_df: DataFrame, county_list: list, types: list):
    check_pairs = F.udf(
        lambda pair: True if pair in county_list else False, BooleanType()
    )

    native_cond = (check_pairs(F.array(F.col("county"), F.col("stateorprovince")))) & (
        F.col("type").isin(types)
    )

    output_df = source_df.withColumn(
        "canbenative", F.when(native_cond == True, True).otherwise(False)
    )

    return output_df


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

    predictions = linker.predict(
        threshold_match_probability=splink_config["THRESHOLD_MATCH_PROBABILITY"]
    )
    clusters = linker.cluster_pairwise_predictions_at_threshold(
        predictions,
        threshold_match_probability=splink_config["THRESHOLD_MATCH_PROBABILITY"],
    )

    clusters_df = ps.from_pandas(clusters.as_pandas_dataframe()).to_spark()

    return clusters_df


def generate_globalids_and_native_records(
    source_df: DataFrame, order_key: str = "orghubid"
):
    null_global_ids_df = source_df.where(source_df["orgglobalidentifier"].isNull())
    not_null_count = source_df.where(
        source_df["orgglobalidentifier"].isNotNull()
    ).count()

    windowSpec = Window.orderBy(F.col(order_key).desc())

    filled_global_ids_df = null_global_ids_df.withColumn(
        "new_orgglobalidentifier",
        F.concat(
            F.lit("ORG"),
            F.lpad(F.row_number().over(windowSpec) + not_null_count, 8, "0"),
        ),
    )

    global_id_df = (
        source_df.join(
            filled_global_ids_df,
            source_df["bdmporgkey"] == filled_global_ids_df["bdmporgkey"],
            how="leftouter",
        )
        .select(source_df["*"], filled_global_ids_df["new_orgglobalidentifier"])
        .withColumn(
            "orgglobalidentifier",
            F.when(
                source_df["orgglobalidentifier"].isNotNull(),
                source_df["orgglobalidentifier"],
            ).otherwise(filled_global_ids_df["new_orgglobalidentifier"]),
        )
        .drop("new_orgglobalidentifier")
    )

    global_id_df.createOrReplaceTempView("bright_participants_df")

    output_df = spark.sql(native_records_query)
    return output_df


def write_table(
    input_df: DataFrame,
    data_bucket: str,
    data_layer: str,
    table: str,
    database: str,
    max_records_per_file: int,
    partition_col: str,
    partition_value: str,
):
    writer_df = (
        input_df.withColumn(partition_col, F.lit(partition_value))
        .write.format("parquet")
        .option(
            "path",
            f"s3://{data_bucket}/{data_layer}/{database}/{table}/",
        )
        .option("maxRecordsPerFile", max_records_per_file)
        .option("compression", "snappy")
        .partitionBy(partition_col)
    )

    table_exists = spark.catalog._jcatalog.tableExists(f"{database}.{table}")

    if table_exists:
        writer_df.mode("append").save()
        spark.sql(
            f"ALTER TABLE {database}.{table} ADD IF NOT EXISTS PARTITION ({partition_col}='{partition_value}');"
        )
    else:
        writer_df.mode("overwrite").saveAsTable(f"{database}.{table}")


if __name__ == "__main__":
    params = [
        "JOB_NAME",
        "TempDir",
        "config_bucket",
        "model_version",
        "data_bucket",
        "glue_db",
        "alaya_glue_db",
        "office_table_name",
        "team_table_name",
        "ssm_params_base",
        "aurora_table",
        "county_info_s3_path",
        "max_records_per_file",
        "aurora_connection_name",
        "alaya_trigger_key",
    ]

    args = getResolvedOptions(sys.argv, params)

    s3 = boto3.client("s3")

    sc = SparkContext()
    sc.setCheckpointDir(args["TempDir"])
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    # Read clean office and team data
    splink_clean_office_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['office_table_name']}/"
    office_df = spark.read.format("delta").load(splink_clean_office_data_s3_path)

    splink_clean_team_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['team_table_name']}/"
    team_df = spark.read.format("delta").load(splink_clean_team_data_s3_path)

    office_df = office_df.withColumn("orgsourcetype", F.lit("OFFICE"))
    team_df = team_df.withColumn("orgsourcetype", F.lit("TEAM"))

    # Run splink model over office and team data
    clusters_df = deduplicate_entity(
        entity="office",
        spark_df=office_df,
        spark=spark,
        splink_model_path="/tmp/office_splink_model.json",
    )

    # Retrieve native record county rules from s3
    # and generate a county list with all the counties that are Bright Participants
    county_df = ps.read_csv(args["county_info_s3_path"])

    bright_participants = county_df.groupby("Native/Bordering").get_group("Native")
    county_list = (
        bright_participants[["Upper County", "State"]].values.tolist()
        + bright_participants[["County Name", "State"]].values.tolist()
    )

    native_df = generate_canbenative_col(clusters_df, county_list, office_types)
    native_df.createOrReplaceTempView("dedup_office_df")

    dedup_team_df = deduplicate_entity(
        entity="team",
        spark_df=team_df,
        spark=spark,
        splink_model_path="/tmp/team_splink_model.json",
    )
    dedup_team_df.createOrReplaceTempView("dedup_team_df")
    for field in dedup_team_df.schema:
        if field.dataType == NullType():
            dedup_team_df = dedup_team_df.withColumn(
                field.name, F.col(field.name).cast("string")
            )

    # Format office data as needed for the organizations table
    org_office_df = spark.sql(office_sql_map_query)

    # Format team data as needed for the organizations table
    org_team_df = spark.sql(team_sql_map_query)

    # Generate new organizations table
    organization_changes_df = org_office_df.unionByName(org_team_df)

    # Get current organizations table from Aurora
    try:
        conn_ops = {
            "useConnectionProperties": "True",
            "dbtable": args["aurora_table"],
            "connectionName": args["aurora_connection_name"],
        }
        cur_org_df = glueContext.create_dynamic_frame_from_options(
            connection_type="postgresql", connection_options=conn_ops
        ).toDF()

        cur_org_df.createOrReplaceTempView("target_df")
        organization_changes_df.createOrReplaceTempView("changes_df")

        join_query = f"select changes_df.*, target_df.orgglobalidentifier from changes_df left join target_df on changes_df.{merge_key}=target_df.{merge_key}"
        org_changes_df = spark.sql(join_query)

    except Exception as e:
        if 'relation "{table}" does not exist'.format(
            table=args["aurora_table"]
        ) in str(e):
            org_changes_df = organization_changes_df.withColumn(
                "orgglobalidentifier", F.lit(None)
            )
        else:
            print("Aurora Exception: ", str(e))
            raise e

    # Generate global ids and final organizations df
    organizations_df = generate_globalids_and_native_records(org_changes_df)

    # Write data to S3
    partition_col = "dt_utc"
    partition_value = str(datetime.now().strftime("%Y-%m-%d-%H-%M-%S"))

    write_table(
        clusters_df,
        args["data_bucket"],
        "consume_data",
        "splink_office_cluster",
        args["glue_db"],
        int(args.get("max_records_per_file", 1000)),
        partition_col,
        partition_value,
    )

    write_table(
        dedup_team_df,
        args["data_bucket"],
        "consume_data",
        "splink_team_cluster",
        args["glue_db"],
        int(args.get("max_records_per_file", 1000)),
        partition_col,
        partition_value,
    )

    write_table(
        organizations_df,
        args["data_bucket"],
        "consume_data",
        "organizations",
        args["alaya_glue_db"],
        int(args.get("max_records_per_file", 1000)),
        partition_col,
        partition_value,
    )

    # Write data to the Aurora PostgreSQL database
    conn = glueContext.extract_jdbc_conf(args["aurora_connection_name"])

    organizations_df.write.format("jdbc").option("url", conn["fullUrl"]).option(
        "dbtable", args["aurora_table"]
    ).option("user", conn["user"]).option("password", conn["password"]).option(
        "driver", "org.postgresql.Driver"
    ).mode(
        "overwrite"
    ).save()

    # Trigger update alaya process
    update_alaya_payload = {
        "batch": partition_value,
        "table": "organizations",
        "database": args["alaya_glue_db"],
    }

    s3.put_object(
        Bucket=args["data_bucket"],
        Body=json.dumps(update_alaya_payload),
        Key=f"{args['alaya_trigger_key']}/organizations_{partition_value}.json",
    )

    job.commit()

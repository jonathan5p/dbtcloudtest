import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.window import Window
from pyspark.sql.types import BooleanType
import pyspark.sql.functions as F
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import DataFrame
from splink.spark.linker import SparkLinker
import pyspark.pandas as ps
import boto3
import json

# Map teams to organizations structure query
team_sql_map_query = """ 
    SELECT 
        dtf.dlid as bdmporgkey,
        dof.uniqueorgid as orgsourceresouoi,
        '' as orgglobalidentifier,
        '' as orglinkedglobalidentifier ,
        dtf.cluster_id as orghubid,
        CASE WHEN dtf.subsystemlocale in ('BRIGHT_CAAR')
        THEN 'CAAR'
        ELSE 'BirghtMls'
        END as orgsourcename,
        dof.mlsid as orgsourcerecordid,
        dtf.key as orgsourcerecordkey,
        dtf.dlingestionts as orgcreatedtms,
        current_timestamp() as orglastmodifiedtms,
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
        dof.phoneext as orgprimaryphoneext,
        dof.phoneother as orgsecondaryphone,
        dof.fax as orgfax,
        dof.email as orgemail,
        dof.socialmediawebsiteurlorid as orgurl,
        dof.corporatelicense as orglicensenumber,
        dof.dateterminated as orglicenseexpirationdate,
        dof.nationalassociationid as orgnrdsid,
        dof.mainname as orgparentorgname,
        dof.mainmlsid as orgparentorgsourcerecordid,
        dof.mainkey as orgparentorgsourcerecordkey,
        dof.brokermlsid as orgindividualbrokerid,
        dof.brokerkey as orgindividualbrokerkey,
        dof.dateadded as orgstartdate,
        dof.dateterminated as orgexpirationdate,
        'OIDH' as orgsourcetransport,
        dof.tradingas as orgtradingasname,
        dtf.key as orgalternatesourcerecordkey,
        dof.dateadded as sourcesystemcreatedtms,
        dtf.modificationtimestamp as sourcesystemmodtms 
    FROM dedup_team_df as dtf
    LEFT JOIN dedup_office_df as dof ON dtf.mlsid__office = dof.mlsid
    """

# Map offices to organizations structure query
office_sql_map_query = """ 
    SELECT 
        dedup_office_df.dlid as bdmporgkey,
        dedup_office_df.uniqueorgid as orgsourceresouoi,
        '' as orgglobalidentifier,
        '' as orglinkedglobalidentifier,
        dedup_office_df.cluster_id as orghubid,
        CASE WHEN dedup_office_df.subsystemlocale in ('BRIGHT_CAAR')
        THEN 'CAAR'
        ELSE 'BirghtMls'
        END as orgsourcename,
        dedup_office_df.mlsid as orgsourcerecordid,
        dedup_office_df.key as orgsourcerecordkey,
        dedup_office_df.dlingestionts as orgcreatedtms,
        current_timestamp() as orglastmodifiedtms,
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
        dedup_office_df.phoneext as orgprimaryphoneext,
        dedup_office_df.phoneother as orgsecondaryphone,
        dedup_office_df.fax as orgfax,
        dedup_office_df.email as orgemail,
        dedup_office_df.socialmediawebsiteurlorid as orgurl,
        dedup_office_df.corporatelicense as orglicensenumber,
        dedup_office_df.dateterminated as orglicenseexpirationdate,
        dedup_office_df.nationalassociationid as orgnrdsid,
        dedup_office_df.mainname as orgparentorgname,
        dedup_office_df.mainmlsid as or gparentorgsourcerecordid,
        dedup_office_df.mainkey as orgparentorgsourcerecordkey,
        dedup_office_df.brokermlsid as orgindividualbrokerid,
        dedup_office_df.brokerkey as orgindividualbrokerkey,
        dedup_office_df.dateadded as orgstartdate,
        dedup_office_df.dateterminated as orgexpirationdate,
        'OIDH' as orgsourcetransport,
        dedup_office_df.tradingas as orgtradingasname,
        dedup_office_df.key as orgalternatesourcerecordkey,
        dedup_office_df.dateadded as sourcesystemcreatedtms,
        dedup_office_df.modificationtimestamp as sourcesystemmodtms 
    FROM dedup_office_df
    """

# Query that gets native records for each cluster
# and linked global identifiers for each record
native_records_query = """
WITH native_records AS(
    SELECT 
        orghubid, 
        orgisbrightparticipant,
        orgglobalidentifier 
    FROM (  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY orghubid ORDER BY orgglobalidentifier ASC) AS row_num
  FROM bright_participants_df
  WHERE orgisbrightparticipant)
    WHERE row_num = 1
)
SELECT bdf.*,
       CASE WHEN 
       native_records.orgglobalidentifier = bdf.orgglobalidentifier
       THEN  ' '
       ELSE COALESCE(native_records.orgglobalidentifier, '') END as orglinkedglobalidentifier
FROM bright_participants_df as bdf 
LEFT JOIN native_records ON bdf.orghubid = native_records.orghubid
ORDER BY bdf.orghubid DESC
"""

# Define merge_key var as primary key of the organizations table
merge_key = "bdmporgkey"


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
    source_df: DataFrame, county_list: list, order_key: str = "orgglobalidentifier"
):
    windowSpec = Window.orderBy(F.col(order_key).desc())

    global_id_df = source_df.withColumn(
        "orgglobalidentifier",
        F.when(
            F.col("orgglobalidentifier").isNull(),
            F.concat(F.lit("ORG"), F.lpad(F.row_number().over(windowSpec), 8, "0")),
        ).otherwise(F.col("orgglobalidentifier")),
    ).orderBy("orghubid", ascending=False)

    print("-----------Global Ids----------")
    print(global_id_df.select("orghubid", merge_key, "orgglobalidentifier").show())

    check_pairs = F.udf(
        lambda pair: True if pair in county_list else False, BooleanType()
    )

    bright_participants_df = global_id_df.withColumn(
        "orgisbrightparticipant",
        check_pairs(F.array(F.col("orgcounty"), F.col("orgstate"))),
    )
    bright_participants_df.createOrReplaceTempView("bright_participants_df")

    print("-----------Bright Participants----------")
    print(
        bright_participants_df.select("orghubid", "orgglobalidentifier")
        .groupBy("orghubid")
        .agg(F.count("orgglobalidentifier").alias("conteo"))
        .filter(F.col("conteo") > 1)
        .show()
    )
    print(bright_participants_df.count())
    print(bright_participants_df.select(F.countDistinct("orghubid")).show())
    print(
        bright_participants_df.select(
            "orghubid",
            merge_key,
            "orgglobalidentifier",
            "orgcounty",
            "orgstate",
            "orgisbrightparticipant",
        ).show(40)
    )

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
        "office_table_name",
        "team_table_name",
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

    # Read clean office and team data
    splink_clean_office_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['office_table_name']}/"
    office_df = (
        spark.read.format("delta").load(splink_clean_office_data_s3_path).limit(1000)
    )

    splink_clean_team_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['team_table_name']}/"
    team_df = (
        spark.read.format("delta").load(splink_clean_team_data_s3_path).limit(1000)
    )

    office_df = office_df.withColumn("orgsourcetype", F.lit("OFFICE"))
    team_df = team_df.withColumn("orgsourcetype", F.lit("TEAM"))

    # Run splink model over office and team data
    dedup_office_df = deduplicate_entity(
        entity="office",
        spark_df=office_df,
        spark=spark,
        splink_model_path="/tmp/office_splink_model.json",
    )
    dedup_office_df.createOrReplaceTempView("dedup_office_df")

    dedup_team_df = deduplicate_entity(
        entity="team",
        spark_df=team_df,
        spark=spark,
        splink_model_path="/tmp/team_splink_model.json",
    )
    dedup_team_df.createOrReplaceTempView("dedup_team_df")

    # Format office data as needed for the organizations table
    dedup_office_df = spark.sql(office_sql_map_query)

    # Format team data as needed for the organizations table
    dedup_team_df = spark.sql(team_sql_map_query)

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

    # Generate new organizations table
    organization_changes_df = dedup_office_df.union(dedup_team_df)
    organization_changes_df.createOrReplaceTempView("changes_df")

    # Get current organizations table from Aurora
    try:
        cur_org_df = (
            spark.read.format("jdbc")
            .option("url", jdbcurl)
            .option("user", username)
            .option("password", password)
            .option("dbtable", args["aurora_table"])
            .load()
        )
        cur_org_df.createOrReplaceTempView("target_df")

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

    # Retrieve native record county rules from s3
    # and generate a county list with all the counties that are Bright Participants
    county_df = ps.read_csv(args["county_info_s3_path"])

    bright_participants = county_df.groupby("Bright Participant/Bordering").get_group(
        "Bright Participant"
    )
    county_list = (
        bright_participants[["Upper County", "State"]].values.tolist()
        + bright_participants[["County Name", "State"]].values.tolist()
    )

    # Generate global ids and final organizations df
    organizations_df = generate_globalids_and_native_records(
        org_changes_df, county_list
    )

    print("-----------Organizations DF----------")
    print(
        organizations_df.select(
            "orghubid",
            merge_key,
            "orgglobalidentifier",
            "orgcounty",
            "orgstate",
            "orgisbrightparticipant",
        ).show(40)
    )
    # Write data to S3
    dedup_office_df.write.mode("overwrite").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/splink_office_cluster_df/",
    ).option("overwriteSchema", "true").option("compression", "snappy").saveAsTable(
        f"{args['glue_db']}.splink_office_cluster_df"
    )

    dedup_team_df.write.mode("overwrite").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/splink_team_cluster_df/",
    ).option("overwriteSchema", "true").option("compression", "snappy").saveAsTable(
        f"{args['glue_db']}.splink_team_cluster_df"
    )

    organizations_df.withColumn(
        "dlbatchinsertionts_utc", F.date_trunc("second", F.current_timestamp())
    ).write.mode("overwrite").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/organizations/",
    ).option(
        "overwriteSchema", "true"
    ).option(
        "maxRecordsPerFile", args.get("max_records_per_file", 1000)
    ).option(
        "compression", "snappy"
    ).partitionBy(
        "dlbatchinsertionts_utc"
    ).saveAsTable(
        f"{args['glue_db']}.organizations"
    )

    # Write data to the Aurora PostgreSQL database
    # organizations_df.write.format("jdbc").mode("overwrite").option(
    #    "url", jdbcurl
    # ).option("user", username).option("password", password).option(
    #    "dbtable", args["aurora_table"]
    # ).save()

    job.commit()

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import DataFrame, functions
from splink.spark.linker import SparkLinker
import pyspark.pandas as ps
import boto3
import json


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
    office_df = spark.read.format("parquet").load(splink_clean_office_data_s3_path)

    splink_clean_team_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['team_table_name']}/"
    team_df = spark.read.format("parquet").load(splink_clean_team_data_s3_path)

    office_df = office_df.withColumn("orgsourcetype", functions.lit("OFFICE"))
    team_df = team_df.withColumn("orgsourcetype", functions.lit("TEAM"))

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

    dedup_office_df = spark.sql(office_sql_map_query)

    # Format team data as needed for the organizations table
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

    dedup_team_df = spark.sql(team_sql_map_query)

    # Get full organizations table
    org_df = dedup_office_df.union(dedup_team_df)

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

    org_df.write.mode("overwrite").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/organizations/",
    ).option("overwriteSchema", "true").option("compression", "snappy").saveAsTable(
        f"{args['glue_db']}.organizations"
    )

    # Write data to the Aurora PostgreSQL database
    username = ssm.get_parameter(
        Name=f"/secure/{args['ssm_params_base']}/username", WithDecryption=True
    )["Parameter"]["Value"]
    jdbcurl = ssm.get_parameter(Name=f"/parameter/{args['ssm_params_base']}/jdbc_url")[
        "Parameter"
    ]["Value"]
    password = ssm.get_parameter(
        Name=f"/secure/{args['ssm_params_base']}/password", WithDecryption=True
    )["Parameter"]["Value"]

    org_df.write.format("jdbc").mode("overwrite").option("url", jdbcurl).option(
        "user", username
    ).option("password", password).option("dbtable", args["aurora_table"]).save()

    job.commit()

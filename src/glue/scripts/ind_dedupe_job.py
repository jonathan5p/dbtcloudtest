import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import DataFrame, SparkSession
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from splink.spark.linker import SparkLinker
import pyspark.pandas as ps
import boto3
import json

# Generate individuals table query
sql_map_query = """ 
SELECT 
    cs_df.dlid as bdmpindkey,
    cs_df.key as indsourcerecordid,
    cs_df.mlsid as indsourcerecordkey,
    cs_df.officekey as indorgid,
    cs_df.officemlsid as indorgsourcerecordid,
    '' as indglobalidentifier,
    '' as indgloballinkedidentifier,
    cs_df.cluster_id as indhubid,
    cs_df.firstname as indfirstname,
    cs_df.lastname||' '||cs_df.namesuffix  as indlastname,
    cs_df.middleinitial as indmiddleinitial,
    cs_df.fullname as indfullname,
    cs_df.preferredfirstname||' '||cs_df.preferredlastname as indalternatename,
    upper(cs_df.address) as indstreetaddress,
    upper(cs_df.city) as indaddresscity,
    cs_df.stateorprovince as indaddressstate,
    cs_df.postalcode as indaddresspostalcode,
    off_df.officecounty as indaddresscounty,
    CASE WHEN cs_df.country = 'US' 
    THEN 'USA' 
    ELSE upper(cs_df.country) END as indaddresscountry,
    cs_df.email as indpublicemail,
    cs_df.privateemail as indprivateemail,
    cs_df.socialmediawebsiteurlorid as indurl,
    cs_df.preferredphone as indprimaryphone,
    cs_df.preferredphoneext as indprimaryphoneext,
    cs_df.directphone as indsecondaryphone,
    cs_df.mobilephone as indmobilephone,
    cs_df.officephone as indofficephone,
    cs_df.officephoneext as indofficephoneext,
    cs_df.nationalassociationid as indnrdsid,
    cs_df.type||' '||cs_df.subtype as indtype,
    cs_df.status as indstatus,
    cs_df.joindate as indjoindate,
    cs_df.terminationdate as indterminateddate,
    cs_df.dateadded as sourcesystemcreatedtms,
    cs_df.modificationtimestamp as sourcesystemmodtms,
    'OIDH' as indsourcetransport,
    cs_df.subsystemlocale as indsourcename,
    cs_df.uniqueorgid as indsourceresouoi,
    '' as indexpirationdate,
    cs_df.dlingestionts as indcreatedts,
    current_timestamp() as indlastmodifiedts
FROM clusters_df as cs_df
LEFT JOIN office_df as off_df ON cs_df.officemlsid = off_df.officemlsid
"""


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
        "agent_table_name",
        "office_table_name",
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

    # Read clean agent data and enrich office data
    splink_clean_data_s3_path = f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/{args['agent_table_name']}/"
    clean_df = spark.read.format("parquet").load(splink_clean_data_s3_path)
    clean_df.createOrReplaceTempView("clean_df")

    office_data_s3_path = f"s3://{args['data_bucket']}/staging_data/{args['glue_db']}/{args['office_table_name']}/"
    office_df = spark.read.format("delta").load(office_data_s3_path)
    office_df.createOrReplaceTempView("office_df")

    # Run splink model over office and team data
    dedup_office_df = deduplicate_entity(
        entity="agent",
        spark_df=clean_df,
        spark=spark,
        splink_model_path="/tmp/agent_splink_model.json",
    )
    dedup_office_df.createOrReplaceTempView("clusters_df")

    # Generate individuals table
    individuals_df = spark.sql(sql_map_query)

    # Write data to S3
    individuals_df.write.mode("overwrite").format("parquet").option(
        "path",
        f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/individuals/",
    ).option("overwriteSchema", "true").option("compression", "snappy").saveAsTable(
        f"{args['glue_db']}.individuals"
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

    individuals_df.write.format("jdbc").mode("overwrite").option("url", jdbcurl).option(
        "user", username
    ).option("password", password).option("dbtable", args["aurora_table"]).save()

    job.commit()

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import pyspark.sql.functions as F
from pyspark.sql import Window, DataFrame, SparkSession
from pyspark.sql.types import *
from delta import DeltaTable
import json
import requests
import boto3

geo_args_order = ["address", "city", "county", "state", "postalcode"]


@F.udf(returnType=MapType(StringType(), StringType()))
def get_geo_info(address, city, county, state, postalcode, country="US"):
    """
    Auxiliar function to get CAAR county data
    """

    output = None
    payload = {
        "streetAddress": address,
        "cityName": city,
        "countyName": county,
        "stateName": state,
        "postalCode": postalcode,
        "country": country,
    }

    if address != None:
        try:
            response = requests.get(api_uri, params=payload)
            if response.status_code == requests.codes.ok:
                output = response.json()
            else:
                output = {
                    "statusCode": response.status_code,
                    "apiResponse": response.text,
                }
        except Exception as e:
            print(e)

    return output


def get_geo_info_df(geo_cols: dict, input_df: DataFrame, repartition_num: int):
    if geo_cols not in [{}, None]:
        try:
            geo_cols = [F.col(geo_cols[arg_name]) for arg_name in geo_args_order]
            output_df = input_df.repartition(repartition_num).withColumn(
                "geo_info", get_geo_info(*geo_cols)
            )
        except KeyError as e:
            raise KeyError(
                f"Key {str(e)} not found in geo_cols argument.\nThe geo_cols argument must contain the keys [address,city,county,state,postalcode] with their respective value."
            )
    else:
        raise ValueError(
            "The geo_cols argument must contain the keys [address,city,county,state,postalcode] with their respective value."
        )
    return output_df


def first_load(
    target_path: str,
    target_table: str,
    geo_cols: str,
    repartition_num: int,
    compression: str = "snappy",
    database: str = "default",
    source_table: str = "test_table",
    test: bool = False,
):
    input_df = spark.read.format("delta").table(f"{database}.{source_table}")
    insert_df = get_geo_info_df(geo_cols, input_df, repartition_num)
    number_of_files = int(repartition_num // 10) if repartition_num // 10 != 0 else 1

    write_df = (
        insert_df.repartition(number_of_files)
        .write.mode("overwrite")
        .format("delta")
        .option("path", target_path)
        .option("overwriteSchema", "true")
        .option("compression", compression)
    )

    if test:
        write_df.save()
    else:
        write_df.saveAsTable(f"{database}.{target_table}")
        spark.sql(
            f"ALTER TABLE {database}.{target_table} SET TBLPROPERTIES (delta.enableChangeDataFeed = true)"
        )


def incremental_load(
    spark: SparkSession,
    geo_cols: str,
    latest_df: DataFrame,
    database: str,
    table: str,
    merge_key: str,
):
    changes_df = latest_df.filter(
        F.col("_change_type").isin(["update_postimage", "insert"])
    )
    delete_df = latest_df.filter(F.col("_change_type") == "delete")
    updates_df = get_geo_info_df(geo_cols, changes_df)
    upsert_df = updates_df.unionByName(delete_df, allowMissingColumns=True)
    target_df = DeltaTable.forName(spark, f"{database}.{table}")

    target_df.alias("target").merge(
        upsert_df.alias("updates"), f"target.{merge_key} = updates.{merge_key}"
    ).whenMatchedUpdateAll(
        condition=(F.col("_change_type") == "update_postimage")
    ).whenMatchedDelete(
        condition=(F.col("_change_type") == "delete")
    ).whenNotMatchedInsertAll().execute()


if __name__ == "__main__":
    global api_uri

    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "table",
            "data_bucket",
            "geo_api_parameter",
            "database",
            "options",
        ],
    )

    ssm = boto3.client("ssm")
    api_endpoint = ssm.get_parameter(Name=args["geo_api_parameter"])["Parameter"][
        "Value"
    ]
    api_uri = api_endpoint + "geoCodeAddressFull"

    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    options = json.loads(args["options"])
    geo_cols = options["geoinfo_config"]["geoinfo_cols"]
    entity = options["geoinfo_config"]["entity"]
    repartition_num = int(options["geoinfo_config"]["repartition_num"])

    write_options = options["write_options"]
    merge_key = write_options.get("merge_key")

    staging_table = args["table"].replace("raw", "staging")
    table_exists = spark._jsparkSession.catalog().tableExists(
        args["database"], staging_table
    )

    if not table_exists:
        first_load(
            target_path=f"s3://{args['data_bucket']}/staging_data/{args['database']}/{staging_table}",
            target_table=staging_table,
            geo_cols=geo_cols,
            database=args["database"],
            source_table=args["table"],
            repartition_num=repartition_num,
        )
    elif table_exists:
        cdc_df = (
            spark.read.option("readChangeFeed", "true")
            .option("startingVersion", "1")
            .format("delta")
            .table(f"{args['database']}.{args['table']}")
        )

        latest_df = (
            cdc_df.withColumn(
                "latest_version",
                F.max("_commit_version").over(
                    Window.orderBy(F.col("_commit_timestamp").desc())
                ),
            )
            .filter("_commit_version = latest_version")
            .drop("latest_version")
        )

        print(
            "Latest Changes: \n",
            latest_df.select(
                "_commit_version", "_change_type", "_commit_timestamp"
            ).show(10),
        )

        incremental_load(
            spark, geo_cols, latest_df, args["database"], staging_table, merge_key
        )
job.commit()

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import pyspark.sql.functions as F
from pyspark.sql import Window, DataFrame, SparkSession
from pyspark.sql.types import *
from delta import DeltaTable
import json

state_abb2name = {
    "AL": "Alabama",
    "AK": "Alaska",
    "AZ": "Arizona",
    "AR": "Arkansas",
    "CA": "California",
    "CO": "Colorado",
    "CT": "Connecticut",
    "DE": "Delaware",
    "FL": "Florida",
    "GA": "Georgia",
    "HI": "Hawaii",
    "ID": "Idaho",
    "IL": "Illinois",
    "IN": "Indiana",
    "IA": "Iowa",
    "KS": "Kansas",
    "KY": "Kentucky",
    "LA": "Louisiana",
    "ME": "Maine",
    "MD": "Maryland",
    "MA": "Massachusetts",
    "MI": "Michigan",
    "MN": "Minnesota",
    "MS": "Mississippi",
    "MO": "Missouri",
    "MT": "Montana",
    "NE": "Nebraska",
    "NV": "Nevada",
    "NH": "New Hampshire",
    "NJ": "New Jersey",
    "NM": "New Mexico",
    "NY": "New York",
    "NC": "North Carolina",
    "ND": "North Dakota",
    "OH": "Ohio",
    "OK": "Oklahoma",
    "OR": "Oregon",
    "PA": "Pennsylvania",
    "RI": "Rhode Island",
    "SC": "South Carolina",
    "SD": "South Dakota",
    "TN": "Tennessee",
    "TX": "Texas",
    "UT": "Utah",
    "VT": "Vermont",
    "VA": "Virginia",
    "WA": "Washington",
    "WV": "WestVirginia",
    "WI": "Wisconsin",
    "WY": "Wyoming",
}


@F.udf(returnType=StringType())
def get_geo_info(city, state):
    """
    Auxiliar function to get CAAR county data
    """
    geolocator = Nominatim(user_agent="geoapp", timeout=15)
    geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1)

    output = None
    if city is not None:
        query = city + ", " + state_abb2name.get(state, "")
        location = geocode(
            query,
            country_codes=["us"],
            addressdetails=True,
            featuretype="",
        )

        if location is not None:
            address = location.raw.get("address")
            output = (
                address.get("county", address.get("city", address.get("town")))
                if address != None
                else None
            )

    return output


def get_geo_info_df(geo_cols: str, input_df: DataFrame):
    geo_cols = geo_cols.split(",")
    if geo_cols not in ["", None]:
        geo_cols = [F.col(col_name) for col_name in geo_cols]
        output_df = input_df.withColumn("geo_info", get_geo_info(*geo_cols))
    else:
        raise ValueError(
            "The geo_cols argument must contain n columns following the order: [WIP]"
        )
    return output_df


def first_load(
    target_path: str,
    target_table: str,
    geo_cols: str,
    entity: str,
    compression: str = "snappy",
    database: str = "default",
    source_table: str = "test_table",
    test: bool = False,
    tmp: bool = False,
):
    input_df = spark.read.format("delta").table(f"{database}.{source_table}")

    if tmp:
        # TODO Tmp until we get access to the geosvc API
        caar_cond = (F.col(f"{entity}subsystemlocale") == "BRIGHT_CAAR") & (
            F.col(f"{entity}city") != "OTHER"
        )

        #print("Caar count: ", input_df.filter(caar_cond).count())

        geo_cols = geo_cols.split(",")
        geo_cols = [F.col(col_name) for col_name in geo_cols]

        insert_df = input_df.withColumn(
            f"{entity}county",
            F.when(caar_cond, get_geo_info(*geo_cols)).otherwise(
                F.col(f"{entity}county")
            ),
        )
    else:
        insert_df = (
            get_geo_info_df(geo_cols, input_df)
            .withColumn(f"{entity}county", F.col("geo_info"))
            .drop("geo_info")
        )

    write_df = (
        insert_df.write.mode("overwrite")
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
    entity: str,
):
    changes_df = latest_df.filter(
        F.col("_change_type").isin(["update_postimage", "insert"])
    )
    delete_df = latest_df.filter(F.col("_change_type") == "delete")

    updates_df = (
        get_geo_info_df(geo_cols, changes_df)
        .withColumn(f"{entity}county", F.col("geo_info"))
        .drop("geo_info")
    )

    upsert_df = updates_df.unionByName(delete_df)

    target_df = DeltaTable.forName(spark, f"{database}.{table}")

    target_df.alias("target").merge(
        upsert_df.alias("updates"), f"target.{merge_key} = updates.{merge_key}"
    ).whenMatchedUpdate(
        condition=(F.col("_change_type") == "update_postimage"),
        set={f"{entity}county": f"updates.{entity}county"},
    ).whenMatchedDelete(
        condition=(F.col("_change_type") == "delete")
    ).whenNotMatchedInsertAll().execute()


if __name__ == "__main__":
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "table",
            "data_bucket",
            "database",
            "options",
        ],
    )

    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    options = json.loads(args["options"])
    geo_cols = options["geoinfo_config"]["geoinfo_cols"]
    entity = options["geoinfo_config"]["entity"]

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
            entity=entity,
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

        write_options = options["write_options"]
        merge_key = write_options.get("merge_key")

        incremental_load(
            spark,
            geo_cols,
            latest_df,
            args["database"],
            staging_table,
            merge_key,
            entity,
        )
job.commit()

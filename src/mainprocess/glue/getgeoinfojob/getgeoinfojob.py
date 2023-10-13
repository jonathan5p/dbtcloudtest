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
def get_geo_info(city, state, country):
    """
    Auxiliar function to get CAAR county data
    """
    geolocator = Nominatim(user_agent="geoapp", timeout=15)
    geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1 / 100)

    output = None
    if city is not None:
        query = city + ", " + state_abb2name.get(state, "")
        location = geocode(
            query,
            country_codes=[country],
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
    geo_cols = args["geoinfo_cols"].split(",")
    if geo_cols not in ["", None]:
        geo_cols = [F.col(col_name) for col_name in geo_cols]
        output_df = input_df.withColumn("officecounty", get_geo_info(*geo_cols))
    else:
        raise ValueError(
            "The geo_cols argument must contain n columns following the order: [WIP]"
        )
    return output_df


def first_load(
    target_path: str,
    target_table: str,
    geo_cols: str,
    compression: str = "snappy",
    database: str = "default",
    source_table: str = "test_table",
    test: bool = False,
):
    input_df = spark.read.format("delta").table(f"{database}.{source_table}")

    insert_df = get_geo_info_df(geo_cols, input_df)

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
):
    changes_df = latest_df.filter(
        F.col("_change_type").isin(["update_postimage", "insert"])
    )

    changes_df.printSchema()
    print(
        changes_df.select(
            "officemlsid", "_change_type", "_commit_version", "_commit_timestamp"
        ).show()
    )    

    upsert_df = get_geo_info_df(geo_cols, changes_df)

    target_df = DeltaTable.forName(spark, f"{database}.{table}")

    target_df.alias("target").merge(
        upsert_df.alias("updates"), f"target.{merge_key} = updates.{merge_key}"
    ).whenMatchedUpdate(
        set={"officecounty": "updates.officecounty"}
    ).whenNotMatchedInsertAll().execute()


if __name__ == "__main__":
    args = getResolvedOptions(
        sys.argv,
        ["JOB_NAME", "table", "data_bucket", "database", "geoinfo_cols"],
    )

    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    staging_table = args["table"].replace("raw", "staging")

    table_exists = spark._jsparkSession.catalog().tableExists(
        args["database"], staging_table
    )

    if not table_exists:
        first_load(
            target_path=f"s3://{args['data_bucket']}/staging_data/{args['database']}/{staging_table}",
            target_table=staging_table,
            geo_cols=args["geoinfo_cols"],
            database=args["database"],
            source_table=args["table"],
        )
    elif table_exists:
        cdc_df = (
            spark.read.option("readChangeFeed", "true")
            .option("startingVersion", "1")
            .format("delta")
            .table(f"{args['database']}.{args['table']}")
        )

        cdc_df.printSchema()
        print(
            cdc_df.select(
                "officemlsid", "_change_type", "_commit_version", "_commit_timestamp"
            ).show()
        )

        latest_df = (
            cdc_df.withColumn(
                "latest_version",
                F.max("_commit_version").over(
                    Window.orderBy(F.col("_commit_timestamp").desc())
                ),
            )
            .filter("_commit_version = latest_version")
            .drop("maxdate")
        )

        print(
            latest_df.select(
                "officemlsid", "_change_type", "_commit_version", "_commit_timestamp"
            ).show()
        )

        merge_key = "officemlsid"
        incremental_load(
            spark,
            args["geoinfo_cols"],
            latest_df,
            args["database"],
            staging_table,
            merge_key,
        )
job.commit()

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import pyspark.sql.functions as F
from pyspark.sql import Window
from pyspark.sql.types import *

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


## @params: [JOB_NAME]
args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "table", "data_bucket", "database", "geoinfo_cols"],
)

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

df = (
    spark.read.option("readChangeFeed", "true")
    .option("startingVersion", "1")
    .format("delta")
    .table(f"{args['database']}.{args['table']}")
    .limit(10)
)

df.printSchema()
print(
    df.select(
        "officemlsid", "_change_type", "_commit_version", "_commit_timestamp"
    ).show()
)

df2 = (
    df.withColumn(
        "latest_version",
        F.max("_commit_version").over(
            Window.orderBy(F.col("_commit_timestamp").desc())
        ),
    )
    .filter("_commit_version = latest_version")
    .drop("maxdate")
)

print(
    df2.select(
        "officemlsid", "_change_type", "_commit_version", "_commit_timestamp"
    ).show()
)

upsert_df = df2.filter(F.col("_change_type").isin(["update_postimage","insert"]))

geo_cols = args["geoinfo_cols"].split(",")
if geo_cols not in ["", None]:
    geo_cols = [F.col(col_name) for col_name in geo_cols]
    new_county_df = upsert_df.withColumn("new_county", get_geo_info(*geo_cols))
else:
    raise ValueError(
        "The geo_cols argument must contain n columns following the order: [WIP]"
    )

job.commit()

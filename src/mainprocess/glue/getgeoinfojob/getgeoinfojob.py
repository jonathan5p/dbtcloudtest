import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
from pyspark.sql.functions import udf, col
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

@udf(returnType=MapType(StringType(),StringType()))
def get_geo_info(city, state, country):
    """
    Auxiliar function to get CAAR county data
    """
    geolocator = Nominatim(user_agent="geoapp", timeout=15)
    geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1 / 100)
    
    output = None
    if city is not None:
        query = (
            city + ", " + state_abb2name.get(state, "")
        )
        location = geocode(
            query,
            country_codes=[country],
            addressdetails=True,
            featuretype="",
        )

        if location is not None:
            output = location.raw.get("address")

    return output

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

df = spark.read.format("delta")\
          .table("aue1d1z1gldoidhoidh_oidhdb.bright_raw_office_latest")\
          .limit(10)

df2 = df.withColumn("geoinfo", get_geo_info(col("officecity"), col("officestateorprovince"), col("officecountry")))
        
print(df2.select(col("geoinfo"), col("geoinfo")["county"].alias("county")).show(truncate=False))
df2.printSchema()

#df.printSchema()
#print(df.select("membermlsid","_change_type", "_commit_version", "_commit_timestamp").show())



job.commit()
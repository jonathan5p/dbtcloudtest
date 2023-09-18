from deltalake.writer import write_deltalake
from deltalake import DeltaTable
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import awswrangler as wr
import pandas as pd
from datetime import datetime, timedelta
import time
import logging
import os

# Logger initialization
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

if os.environ.get("TEST") is None:
    # Env variables
    s3_source_path = os.environ["S3_SOURCE_PATH"]
    s3_target_path = os.environ["S3_TARGET_PATH"]

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

uoi_mapper = {"BRIGHT_CAAR": "A00001567", "Other": "M00000309"}


def get_geo_info(row, geocode):
    """
    Auxiliar function to get CAAR county data
    """
    output = None
    if row.officecity is not None:
        query = (
            row.officecity + ", " + state_abb2name.get(row.officestateorprovince, "")
        )
        location = geocode(
            query,
            country_codes=[row.officecountry],
            addressdetails=True,
            featuretype="",
        )

        if location is not None:
            output = location.raw.get("address")

    return output

def set_delta_df(delta_table:pd.DataFrame):
    
    delta_table = delta_table.set_index("dlid")
    start_time = time.time()

    # Get valid CAAR data
    time_delta = datetime.now() - timedelta(hours=23)
    filter_df = delta_table.loc[
        (
            (delta_table["officesubsystemlocale"] == "BRIGHT_CAAR")
            & (delta_table["officecity"] != "OTHER")
            & (delta_table["dllastmodificationts"] >= time_delta)
        ),
        :,
    ].copy()
    logger.info("Filtered rows: {}".format(filter_df.shape[0]))

    if filter_df.shape[0] > 0:
        # Get county information for all rows in filter_df
        geolocator = Nominatim(user_agent="my-app", timeout=15)
        geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1 / 100)

        filter_df.loc[:, "geo_info"] = filter_df.apply(
            get_geo_info, geocode=geocode, axis=1
        )
        filter_df.loc[:, "county"] = filter_df["geo_info"].apply(
            lambda x: x.get("county", x.get("city", x.get("town")))
            if x != None
            else None
        )

        # Update rows with the new county data
        delta_table.loc[filter_df.index, :] = filter_df.drop("geo_info", axis=1)

        end_time = time.time()
        logger.info("Get county info time: {}".format(end_time - start_time))

    # Create Unique Organization Identifier column
    delta_table.loc[:, "uniqueorgid"] = delta_table.apply(
        lambda x: uoi_mapper.get(x.officesubsystemlocale, uoi_mapper["Other"]), axis=1
    )
    delta_table.reset_index(inplace=True)
    return delta_table

def lambda_handler(event, context):
    """
    Add county information for CAAR data and Unique Organization Id
    """
    start_time = time.time()

    # Read delta table from s3 path
    delta_table = wr.s3.read_deltalake(path=s3_source_path)

    end_time = time.time()
    logger.info("Read time: {}".format(end_time - start_time))

    delta_table = set_delta_df(delta_table)

    start_time = time.time()
    # Write delta lake table to s3
    write_deltalake(
        s3_target_path,
        delta_table,
        mode="overwrite",
        overwrite_schema=True,
        storage_options={"AWS_S3_ALLOW_UNSAFE_RENAME": "true"},
    )

    end_time = time.time()
    logger.info("Writing time: {}".format(end_time - start_time))
    start_time = end_time

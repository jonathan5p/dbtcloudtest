import json
import os
import sys
import pathlib
import pandas as pd
from deltalake import DeltaTable
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter

os.environ["TEST"] = "true"
base_dir = pathlib.Path(__file__).parent.parent.parent.resolve()
sys.path.append(f"{base_dir}/../src/lambda/")

from config_loader.lambda_function import prepare_sf_input
from caar_enrich_office_data.lambda_function import set_delta_df, get_geo_info


def test_sf_input():
    """
    Test that the prepare_sf_input function defined
    in the OIDH config_loader lambda function expected.
    """

    tables_list = json.load(
        open(f"{base_dir}/sample_configs/artifacts/ingest_config.json")
    )
    sf_input = prepare_sf_input(tables_list)

    assert list(sf_input.keys()) == [
        "tables"
    ], f'Step function input expected to be ["tables"], got: {list(sf_input.keys())}'
    assert (
        len(sf_input["tables"]) == 3
    ), f'Number of tables expected to be 3, got: {len(sf_input["tables"])}'


def test_get_geo_info():
    """
    Test that the get_geo_info function defined
    in the OIDH caar_enrich_office_data lambda function works as expected.
    """

    test_df = pd.DataFrame(
        {
            "officecity": ["LANCASTER", "Berlin", "NOBLESVILLE", "RIDGEWOOD"],
            "officestateorprovince": ["PA", "MD", "IN", "NJ"],
            "officecountry": ["US", "US", "US", "US"],
        }
    )

    geolocator = Nominatim(user_agent="my-app", timeout=15)
    geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1 / 100)

    geo_df = test_df.apply(get_geo_info, geocode=geocode, axis=1)
    county = geo_df.apply(
        lambda x: x.get("county", x.get("city", x.get("town"))) if x != None else None
    )

    reference_county = [
        "Lancaster County",
        "Worcester County",
        "Hamilton County",
        "Bergen County",
    ]

    assert (
        county.values.tolist() == reference_county
    ), f"County expected to be {reference_county}, got: {county.values.tolist()}"


def test_set_delta_df():
    """
    Test that the set_delta_df function defined
    in the OIDH caar_enrich_office_data ingest job works as expected.
    """

    local_path = f"{base_dir}/sample_data/raw_data/bright_raw_office_latest/"

    local_df = DeltaTable(local_path).to_pandas()
    delta_df = set_delta_df(local_df)

    reference_path = f"{base_dir}/sample_data/staging_data/office/"
    reference_df = pd.read_parquet(reference_path)

    assert (
        delta_df.shape == reference_df.shape
    ), f"Delta df shape expected to be {reference_df.shape}, got: {delta_df.shape}"
    assert delta_df.info(verbose=False, buf=None) == reference_df.info(
        verbose=False, buf=None
    ), f"Delta df schema expected to be {reference_df.info()}, got: {delta_df.info()}"

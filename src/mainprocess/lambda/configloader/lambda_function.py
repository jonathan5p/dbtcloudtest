import json
import os
import logging
import boto3

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

if os.environ.get("TEST") is None:

    etl_config_key = os.environ["ETL_CONFIG_KEY"]
    artifact_bucket = os.environ["ARTIFACTS_BUCKET"]

    s3_client = boto3.client("s3")


def dict_to_json(dict_to_convert: dict):
    """
    Returns a json string from a python dictionary
    Parameters
    ------------
    dict_to_convert: dict
        python dictionary to convert
    """

    logger.info("attempting to convert python dictionary to a string")
    logger.info(f"the dict = {dict_to_convert}")
    message = json.dumps(dict_to_convert)
    return message


def prepare_sf_input(tables_list: dict):
    sf_input = {"tables": []}

    for table in list(tables_list.values()):
        table["options"] = dict_to_json(table["options"])
        sf_input["tables"].append(table)

    return sf_input


def lambda_handler(event, context):
    try:
        # Retrieve data flow config json from the artifacts bucket
        response = s3_client.get_object(Bucket=artifact_bucket, Key=etl_config_key)

        if response != None:
            # Get list of tables for all data lake layers (landing,staging,analytics)
            tables_list = json.loads(response["Body"].read())
            return prepare_sf_input(tables_list)

    except Exception as exception:
        error_message = "Encountered exeption: " + str(exception)
        raise Exception(error_message)

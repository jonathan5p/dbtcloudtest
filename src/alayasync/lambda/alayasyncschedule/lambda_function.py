import json
import os
import logging
import boto3
import awswrangler as wr

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

max_clusters = 5000

athena_client = boto3.client("athena")
athena_bucket = os.environ["ATHENA_BUCKET"]

payload_bucket = os.environ["PAYLOAD_BUCKET"]
payload_trigger_key = os.environ["PAYLOAD_TRIGGER_KEY"]

s3_client = boto3.client("s3")


def execute_query(query, athena_path):
    query_exec_id = wr.athena.start_query_execution(
        sql=query, s3_output=athena_path, wait=True
    )
    return query_exec_id


def get_clusters(database, table, batch, athena_path):
    query = f""" 
        SELECT 
            distinct cluster_id
        FROM {database}.{table}
        WHERE dt_utc = '{batch}';
        """

    try:
        response = execute_query(query, athena_path)
        print(f"Done with query {query}")

    except Exception as e:
        error = f"Error getting records to transmit: {repr(e)}"
        raise ValueError(f"Initial Query Failed. {error}")

    return response["QueryExecutionId"]


def prepare_sf_input(dfs, payload):
    sf_input = []

    for df in dfs:
        batch = {
            **payload,
            "ids": json.dumps(df["cluster_id"].to_list()),
        }
        sf_input.append(batch)

    return sf_input


def lambda_handler(event, context):
    logger.info(f"Event:{event}")

    payload = {
        "database": event["database"],
        "table": event["table"],
        "batch": event["batch"],
    }

    athena_path = f"s3://{athena_bucket}/initial_query"
    query_id = get_clusters(
        event["database"], event["table"], event["batch"], athena_path
    )
    dfs = wr.athena.get_query_results(
        query_execution_id=query_id, chunksize=max_clusters
    )

    sf_input = prepare_sf_input(dfs, payload)
    logger.info(f"Map input: {sf_input}")

    payload_key = f"{payload_trigger_key}/{event['table']}_{event['batch']}.json"

    s3_client.put_object(
        Bucket=payload_bucket,
        Body=json.dumps(sf_input),
        Key=payload_key,
    )

    response = {"payload_bucket": payload_bucket, "payload_key": payload_key}

    return response

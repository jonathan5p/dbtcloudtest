import awswrangler as wr
import boto3
import json
import logging
import os
import time

from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime

chunk_size = 500
max_records = 5000

logger = logging.getLogger()
logger.setLevel(logging.INFO)

athena_client = boto3.client('athena')
athena_bucket = 'aue1d1z1s3boidhoidh-athena'

dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

projection_expression = "#i, #t, #p, #b, #tbl, #bckt, #k, #db"
index_name = 'scheduling-index'
expression_attributes_names = {"#i": "id", "#t":"last_modified_date", "#p": "status", "#b": "batch", "#tbl": "table", "#bckt": "bucket", "#k": "key", "#db": "database"}

query_parameters = {
        'ProjectionExpression': projection_expression,
        'IndexName': index_name,
        'ExpressionAttributeNames': expression_attributes_names
    }
    
def execute_query(query, athena_bucket, athena_path):

    response = athena_client.start_query_execution(
        QueryString=query,
        ResultConfiguration={
            'OutputLocation': f's3://{athena_bucket}/{athena_path}/',
        }
    )

    return response['QueryExecutionId']

def get_from_dynamo(table, query_parameters):

    response = table.query(**query_parameters)
    logger.info(f'Response:{response}')
    
    validate_response(response)
    records = response.get('Items')

    return records
    
def get_ids_from_payload(payload: list):

    ids = []
    for item in payload:
        ids.append(item['id'])

    return ids
    
def get_query_state(id):

    response = wr.athena.get_query_execution(query_execution_id=id)

    return response['Status']['State']
    
    
def get_records(database, table, dt_utc, athena_bucket, ids):

    query = f""" 
        select 
            "$path" as id, dt_utc, count(*) as num_records 
            from {database}.{table}
            group by 1,2
            having dt_utc = '{dt_utc}'
            and "$path" in ({ids})
            order by num_records desc;
        """
    #print(f"query:{query}")

    try:
        query_id = execute_query(query, athena_bucket, "initial_query")

        wait_on_query(query_id)
        print(f'Done with query {query_id}')

    except Exception as e:

        error = f'Error getting records to transmit: {repr(e)}'
        raise ValueError(f'Initial Query Failed. {error}')

    return query_id
    
def process_records(dfs, payload):

    records = []

    try:

        list_id = []
        num_records = 0
        
        for df in dfs:
                
            for index, row in df.iterrows():
                
                num_records += row['num_records']
                list_id.append(row['id'])
                
                if (num_records > max_records) or (index+1 == df.shape[0]):

                    print(f'n:{num_records}, i:{index}, s:{df.shape[0]}')
                    print(f'l:{",".join(list_id)}')
                    tmp = {'id': ",".join(list_id)}
                    record = {**payload, **tmp}
                    records.append(record)
                    
                    num_records = 0
                    list_id = []
                    
    except Exception as e:

        error = f'Error in initial iteration: {repr(e)}'
        raise ValueError(f'Failed calculating load records. {error}')

    return records

def validate_response(response):

    try:
        status = response.get('ResponseMetadata', {}).get('HTTPStatusCode')

        if status == 200:
            return None

    except Exception as e:
        logger.error(f'Error checking Dynamo response: {repr(e)}')
        raise e
        
def wait_on_query(id):

    try:
        
        stop_states = ['SUCCEEDED']
        continue_states = ['QUEUED','RUNNING']
        failed_states = ['FAILED','CANCELLED']

        status = 'QUEUED'
        
        while status in continue_states:
            status = get_query_state(id)
            time.sleep(20)
            print(f'Query ID: {id} Status: {status}')

        if status in failed_states:
            raise ValueError(f'Query with id: {id} failed')

    except Exception as e:
        raise ValueError(f'Failure waiting for query:{id}. Error: {repr(e)}')

    return status


def lambda_handler(event, context):

    logger.info(f'Event:{event}')

    query_parameters['KeyConditionExpression'] = (Key('batch').eq(event['batch']) & Key('status').eq(event.get('status', 'JUST_ARRIVED')))
    query_parameters['FilterExpression'] = (Attr('table').eq(event['table']) & Attr('database').eq(event['database']))

    records = get_from_dynamo(register_table, query_parameters)
    ids = get_ids_from_payload(records)
    
    if ids:
        
        payload = {
            'batch': event['batch'],
            'bucket': records[0]['bucket'],
            'database': event['database'],
            'status': event['status'],
            'table': event['table'],
        }
        
        list_ids = f""" '{"','".join(ids)}' """
        
        query_id = get_records(event['database'], event['table'], event['batch'], athena_bucket, list_ids)
        dfs = wr.athena.get_query_results(query_execution_id=query_id,chunksize = chunk_size)

        records = process_records(dfs, payload)

    logger.info(f'Response: {records}')
    
    return records
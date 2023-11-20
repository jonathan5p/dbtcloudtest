import awswrangler as wr
import boto3
import json
import logging
import os
import random
import time

from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime
from sync.interfaces.dynamo_interface import DynamoInterface
from sync.interfaces.athena_interface import AthenaInterface

chunk_size = 500
max_records = 5000

athena_bucket = os.environ['ATHENA_BUCKET']
notification_arn = os.environ['LAMBDA_CHATBOT']

logger = logging.getLogger()
logger.setLevel(logging.INFO)

athena_client = boto3.client('athena')
lambda_client = boto3.client('lambda')

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
    
def process_records(dfs, payload, ids):

    records = []
    processing_options = ['lambda_function', 'ecs']

    try:

        list_id = []
        num_records = 0
        total_records = 0
        
        for df in dfs:
            for index, row in df.iterrows():
                
                num_records += row['num_records']
                total_records += row['num_records']
                list_id.append(row['id'])
                ids.remove(row['id'])
                
                if (num_records > max_records) or (index+1 == df.shape[0]):

                    logger.info(f'n:{num_records}, i:{index}, s:{df.shape[0]}')
                    logger.info(f'l:{",".join(list_id)}')
                    tmp = {'id': ",".join(list_id), 'processing_engine': random.choice(processing_options)}
                    record = {**payload, **tmp}
                    records.append(record)
                    
                    num_records = 0
                    list_id = []

    except Exception as e:

        error = f'Error in initial iteration: {repr(e)}'
        raise ValueError(f'Failed calculating load records. {error}')

    return records, ids, total_records

def validate_response(response):

    try:
        status = response.get('ResponseMetadata', {}).get('HTTPStatusCode')

        if status == 200:
            return None

    except Exception as e:
        logger.error(f'Error checking Dynamo response: {repr(e)}')
        raise e
    
def update_record(table, payload):

    query_parameters = {
        'Key': {'id': payload['id']},
        'UpdateExpression': "set #r=:r, #p=:p, #s=:s, #pr=:pr, #t=:t",
        'ExpressionAttributeValues': {':r': payload['records'], ':p': payload['processed_file'], ':s': payload['status'], ':pr': payload['processing_engine'], ':t': payload['task_id']},
        'ExpressionAttributeNames': {"#r": "records", "#p": "processed_file", "#s": "status", "#pr": "processing_engine", "#t": "task_id"},
        'ReturnValues': "UPDATED_NEW"
    }

    response = DynamoInterface(table).update_item(query_parameters)

    return None


def lambda_handler(event, context):
    
    logger.info(f'Event:{event}')

    batch = event['batch']
    database = event['database']
    status = event.get('status', 'JUST_ARRIVED')
    table = event['table']
    primary_key = os.environ[table.upper()]

    query_parameters['KeyConditionExpression'] = (Key('batch').eq(batch) & Key('status').eq(status))
    query_parameters['FilterExpression'] = (Attr('table').eq(table) & Attr('database').eq(database))

    records = get_from_dynamo(register_table, query_parameters)
    ids = get_ids_from_payload(records)
    
    initial_ids = len(ids)
    ids_to_update = []
    total_records = 0
    
    if ids:
        
        payload = {
            'batch': batch,
            'bucket': records[0]['bucket'],
            'database': database,
            'status': status,
            'table': table,
        }
        
        list_ids = f""" '{"','".join(ids)}' """
        
        query_id = AthenaInterface().run_query(
            f"""
                select a."$path" as id, a.dt_utc, count(*) as num_records 
                    from {database}.{table} a 
                    left join {database}.{table}_succeeded as b
                        on 
                            a.{primary_key} = b.{primary_key} and
                            a.dt_utc = b.dt_utc
                    where b.{primary_key} is null and 
                    a.dt_utc = '{batch}' 
                    and a."$path" in ({list_ids})
                group by 1,2
                order by num_records desc;
            """, "select_query", "Error getting records to transmit"
        )

        dfs = wr.athena.get_query_results(query_execution_id=query_id,chunksize = chunk_size)

        records, ids_to_update, total_records = process_records(dfs, payload, ids)
        logger.info(f'Ids to update:{ids_to_update}')
        
        if ids_to_update:
            for id_to_update in ids_to_update:
                payload = {
                    'id': id_to_update,
                    'processed_file': 'No file proccesed',
                    'processing_engine': '',
                    'status': 'SUCCEEDED',
                    'records': {
                        'total' : 0, 
                        'succeeded': 0, 
                        'failed': 0
                        },
                    'task_id': ''
                }
                
                update_record("OIDH_TABLE", payload)
                
    payload_notification = {
        "format": "default",
        "source": "Alaya Sync",
        "description": f"""
            Synchronization process started for table {table}. \n 
            Processing: {initial_ids} Files, Skipped Files:{len(ids_to_update)} \n
            dt_utc: {batch} \n
            Records: {total_records}"""
    }
    
    response = lambda_client.invoke(
        FunctionName=notification_arn,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload_notification)
    )

    logger.info(f'Response: {records}')
    
    return records
from datetime import datetime

from .utils.commons import get_key, get_source_file
from .interfaces.athena_interface import AthenaInterface
from .interfaces.dynamo_interface import DynamoInterface
from jsonschema import validate, exceptions

import awswrangler as wr
import sync.json_data as json_data
import importlib.resources
import json
import pandas as pd

chunk_size = 1500
num_allowed_chars = 150

class recordsFailedException(Exception):
    def __init__(self, message):
        print(message)


def process_records(dfs, source_file, primary_key, event, id, file_name):

    succeeded_df = pd.DataFrame()
    failed_df = pd.DataFrame()
    records = 0

    schema = read_schema(event['table'])

    try:
        for df in dfs:
            print(f'Sending to Alaya')
            records += df.shape[0]

            df['status'] = df.drop(columns=['dt_utc']).apply(send_to_alaya, args=(schema,), axis = 1)
            #df['status'] = df.apply(send_to_cloudwatch, axis = 1)
            df['source_file'] = source_file

            succeeded_df = pd.concat([succeeded_df, df.loc[df['status'] == "True"]])
            failed_df = pd.concat([failed_df, df.loc[df['status'] != "True"]])
            print(f'S:{succeeded_df.shape[0]}, F:{failed_df.shape[0]}')

        succeeded_df = succeeded_df[[primary_key, 'source_file', 'dt_utc']]
        failed_df = failed_df[[primary_key, 'source_file', 'dt_utc', 'status']]

        payload = {
            'id': id,
            'records': {
                'total' : records, 
                'succeeded': succeeded_df.shape[0], 
                'failed': failed_df.shape[0]
            },
            'processed_file': file_name
        }

        print(f'Info:{records}')
        update_record("OIDH_TABLE", payload)


    except recordsFailedException as e:
        raise e
    
    except Exception as e:

        error = f'Error in initial iteration: {repr(e)}'
        raise ValueError(f'Failed sending info to Alaya. {error}')

    return succeeded_df, failed_df


    return None

def read_schema(table):

    if table == 'individuals':
        filename = 'alaya_ind_schema_def.json'
    elif table == 'organizations':
        filename = 'alaya_org_schema_def.json'

    with importlib.resources.open_text(json_data, filename) as f:
        schema = json.load(f)

    return schema

def send_to_alaya(record, schema):

    status = "False"
    
    payload = {
        'lastUpdatedBy': 'abc',
        'lastUpdatedTs': 'abc',
        'documentType': 'abc',
        'content': record.to_dict()
    }

    try:
        result = validate(instance=payload, schema=schema)
        status = "True"
    except exceptions.ValidationError as e:
        print(e)
        print(f'Error: {repr(e)}')
        message = str(e).replace('\n',' ')
        status = f"schema:{message[0:max(len(message),num_allowed_chars)]}"
    except Exception as e:
        pass
    
    return status


def upload_parquet(bucket, key, data):

    try:
        path = f's3://{bucket}/{key}'
        response = wr.s3.to_parquet(df=data, path=path)

    except Exception as e:
        
        error = f'Error uploading file to s3: {repr(e)}'
        raise ValueError(f'Failed sending files to s3://{bucket}/{key}. Error:{error}')
    
    return None

def update_record(table, payload):

    query_parameters = {
        'Key': {'id': payload['id']},
        'UpdateExpression': "set #r=:r, #p=:p",
        'ExpressionAttributeValues': {':r': payload['records'], ':p': payload['processed_file']},
        'ExpressionAttributeNames': {"#r": "records", "#p": "processed_file"},
        'ReturnValues': "UPDATED_NEW"
    }

    response = DynamoInterface(table).update_item(query_parameters)

    return None


def transfer(event):

    print(f"args used: {event}")

    batch = event['batch']
    bucket = event['bucket']
    database = event['database']
    primary_key = event['primary_key']
    table = event['table']
    
    now = datetime.now() 
    date_time = now.strftime("%Y_%m_%d_%H_%M_%S")
    file_name = f'processed_{date_time}.parquet'

    succeeded_table = f'{table}_succeeded'
    failed_table = f'{table}_failed'

    files = event['id'].split(',')

    for id in files:
        
        key = get_key(id, bucket)
        source_file = get_source_file(key)
        print(f"Source File:{source_file}")

        succeeded_key = key.replace(f'/{table}/', f'/{succeeded_table}/').replace(f'/dt_utc={batch}/', f'/dt_utc={batch}/source_file={source_file}/')
        succeeded_key = '/'.join(succeeded_key.split('/')[0:-1]) + f'/{file_name}'
        failed_key = key.replace(f'/{table}/', f'/{failed_table}/').replace(f'/dt_utc={batch}/', f'/dt_utc={batch}/source_file={source_file}/')
        failed_key = '/'.join(failed_key.split('/')[0:-1]) + f'/{file_name}'

        print(f"Succeded key: {succeeded_key}")
        print(f"Failed key: {failed_key}")

        query_id = AthenaInterface().run_query(f"""
            select a.* 
                from {database}.{table} a 
                left join {database}.{succeeded_table} as b
                    on 
                        a.{primary_key} = b.{primary_key} and
                        a.dt_utc = b.dt_utc
                where b.{primary_key} is null and
                a."$path" = '{id}' and 
                a.dt_utc = '{batch}' ""","initial_query", "Error getting records to transmit."
        )

        dfs = wr.athena.get_query_results(query_execution_id=query_id,chunksize = chunk_size)
        
        succeeded_df, failed_df = process_records(dfs, source_file, primary_key, event, id, file_name)


        if not succeeded_df.empty:
            upload_parquet(bucket, succeeded_key, succeeded_df)
        
        if not failed_df.empty:
            upload_parquet(bucket, failed_key, failed_df)

        query_id = AthenaInterface().run_query(f"""
            Alter table {database}.{succeeded_table} 
                add if not exists partition (dt_utc='{batch}', source_file = '{source_file}'); """,
            "add_partition", "Error adding partitions for succeeded table."    
        )

        query_id = AthenaInterface().run_query(f"""
            Alter table {database}.{failed_table} 
                add if not exists partition (dt_utc='{batch}', source_file = '{source_file}'); """,
            "add_partition", "Error adding partitions for succeeded table."    
        )


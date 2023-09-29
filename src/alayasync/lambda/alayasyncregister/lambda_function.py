import boto3
import json
import logging
import re
import os

from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from datetime import datetime, timedelta
from urllib.parse import unquote_plus
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.resource('sqs')
dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

ttl_days = 30 
regex = r"(\bs3://\b){1}([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_]+=[^\/]+)/([a-zA-Z0-9_-]+(\b.parquet\b))$"

def parse_s3_event(s3_event):

    key_parts = unquote_plus(s3_event['s3']['object']['key']).split('/')
    database = key_parts[1]
    table = key_parts[2]
    batch = key_parts[3].split('=')[1]

    return {
        'bucket': s3_event['s3']['bucket']['name'],
        'key': unquote_plus(s3_event['s3']['object']['key']),
        'size': s3_event['s3']['object']['size'],
        'last_modified_date': s3_event['eventTime'].split('.')[0]+'+00:00',
        'timestamp': int(round(datetime.utcnow().timestamp()*1000, 0)),
        'batch': batch,
        'table': table
    }


def put_item(table, item, key):
    try:
        response = table.put_item(
            Item=item,
            ConditionExpression=f"attribute_not_exists({key})",
        )
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            logger.info(e.response['Error']['Message'])
        else:
            raise
    else:
        return response


def delete_item(table, key):
    try:
        response = table.delete_item(
            Key=key
        )
    except ClientError as e:
        logger.error('Fatal error', exc_info=True)
        raise e
    else:
        return response

def get_ttl(days):

    return int((datetime.fromtimestamp(int(time.time())) + timedelta(days=days)).timestamp())

def is_valid(id):

    return re.match(regex, id)

def lambda_handler(event, context):

    try:
        
        logger.info('Received {} messages'.format(len(event['Records'])))
        logger.info(f"Records: {event['Records']}")
        
        for record in event['Records']:
            logger.info('Parsing S3 Event')
            message = json.loads(record['body'])['Records'][0]
            operation = message['eventName'].split(':')[-1]

            id = f's3://{message["s3"]["bucket"]["name"]}/{unquote_plus(message["s3"]["object"]["key"])}'

            if is_valid(id):

                logger.info(f"Performing Dynamo {operation} operation")
                if 'Delete' in operation:
                    delete_item(register_table, {'id': id})
                else:
                    item = parse_s3_event(message)
                    item['id'] = id
                    item['status'] = 'JUST_ARRIVED'
                    item['ttl'] = get_ttl(ttl_days)
                
                    put_item(register_table, item, 'id')

            else:
                logger.info(f"Not valid Id: {id}")

    except Exception as e:
        logger.error('Fatal error', exc_info=True)
        raise e
    return {
        'StatusCode': 200,
        'Status': 'SUCCESS'
    }


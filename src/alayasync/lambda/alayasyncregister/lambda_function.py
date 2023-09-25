import boto3
import json
import logging
import os

from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError

from datetime import datetime
from urllib.parse import unquote_plus

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.resource('sqs')
dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

def parse_s3_event(s3_event):
    return {
        'bucket': s3_event['s3']['bucket']['name'],
        'key': unquote_plus(s3_event['s3']['object']['key']),
        'size': s3_event['s3']['object']['size'],
        'last_modified_date': s3_event['eventTime'].split('.')[0]+'+00:00',
        'timestamp': int(round(datetime.utcnow().timestamp()*1000, 0)),
        'batch': unquote_plus(s3_event['s3']['object']['key']).split('/')[3].split('=')[1]
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


def lambda_handler(event, context):

    try:
        
        logger.info('Received {} messages'.format(len(event['Records'])))
        logger.info(f"Records: {event['Records']}")
        
        for record in event['Records']:
            logger.info('Parsing S3 Event')
            message = json.loads(record['body'])['Records'][0]
            operation = message['eventName'].split(':')[-1]

            logger.info(f"Performing Dynamo {operation} operation")
            if operation == 'Delete':
                id = 's3://{}/{}'.format(
                    message['s3']['bucket']['name'],
                    unquote_plus(message['s3']['object']['key'])
                )
                delete_item(register_table, {'id': id})
            else:
                item = parse_s3_event(message)
                item['id'] = f"s3://{item['bucket']}/{item['key']}"
                item['status'] = 'JUST_ARRIVED'
                
                put_item(register_table, item, 'id')

    except Exception as e:
        logger.error('Fatal error', exc_info=True)
        raise e
    return {
        'StatusCode': 200,
        'Message': 'SUCCESS'
    }


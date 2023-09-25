import boto3
import json
import logging
import os

from boto3.dynamodb.conditions import Key
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

projection_expression = "#i, #t, #p, #b"
index_name = 'scheduling-index'
expression_attributes_names = {"#i": "id", "#t":"last_modified_date", "#p": "status", "#b": "batch"}

query_parameters = {
        'ProjectionExpression': projection_expression,
        'IndexName': index_name,
        'ExpressionAttributeNames': expression_attributes_names
    }

def validate_response(response):

    try:
        status = response.get('ResponseMetadata', {}).get('HTTPStatusCode')

        if status == 200:
            return None

    except Exception as e:
        logger.error(f'Error checking Dynamo response: {repr(e)}')
        raise e

def get_from_dynamo(table, query_parameters):

    response = table.query(**query_parameters)
    logger.info(f'Response:{response}')
    validate_response(response)
    
    records = response.get('Items')

    return records


def lambda_handler(event, context):

    logger.info(f'Event:{event}')

    query_parameters['KeyConditionExpression'] = (Key('batch').eq(event['batch']) & Key('status').eq(event['status']))
    records = get_from_dynamo(register_table, query_parameters)

    logger.info(f'Response: {records}')
    
    return records
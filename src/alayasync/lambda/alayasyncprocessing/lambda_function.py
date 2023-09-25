import boto3
import json
import logging
import os
import random
import time

threshold = 0.6

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

ecs_client = boto3.client('ecs')

def lambda_handler(event, context):
    
    logger.info(f'Event received:{event}')

    id = event['value']['id']
    response = register_table.update_item(
        Key={'id': id},
        UpdateExpression="set #p=:p",
        ExpressionAttributeValues={':p': 'IN_PROGRESS'},
        ExpressionAttributeNames={"#p": "status"},
        ReturnValues="UPDATED_NEW")

    logger.info(f'Response from updates: {response}')
    
    dice = random.random()
    logger.info(f'Dice value:{dice}')

    if dice > threshold:
        raise ValueError(f'Something Failed. Dice value: {dice}')
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Execution Finished: {dice}')
    }
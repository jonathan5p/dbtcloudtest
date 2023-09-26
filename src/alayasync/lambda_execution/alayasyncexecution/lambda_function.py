import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sfn_client = boto3.client('stepfunctions')
sfn_arn = os.environ['SFN']

def lambda_handler(event, context):
    
    logger.info(f'Event received:{event}')

    record = event['Records'][0]
    key = record['s3']['object']['key']

    logger.info(f'Key: {key}')

    payload = {
        'batch': '2021-01-07',
        'status': 'JUST_ARRIVED'
    }

    response = sfn_client.start_execution(
        stateMachineArn=sfn_arn,
        input=json.dumps(payload)
    )

    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Execution Done')
    }
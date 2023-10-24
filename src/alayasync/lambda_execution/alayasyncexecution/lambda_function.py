import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
sfn_client = boto3.client('stepfunctions')
sfn_arn = os.environ['SFN']


def read_from_s3(bucket, key):

    content_object = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = content_object['Body'].read().decode('utf-8')
    json_content = json.loads(file_content)
    
    return json_content

def lambda_handler(event, context):
         
    logger.info(f'Event received:{event}')

    record = event['Records'][0]

    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']

    logger.info(f'Reading: s3://{bucket}/{key}')
    payload = read_from_s3(bucket, key)
    logger.info(f'File content:{payload}')

    response = sfn_client.start_execution(
        stateMachineArn=sfn_arn,
        input=json.dumps(payload)
    )

    logger.info(f'Response from sm: {response}')
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Execution Done')
    }
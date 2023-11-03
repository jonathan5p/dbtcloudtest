import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

cluster_name = os.environ['ECS_CLUSTER']
ecs_client = boto3.client('ecs')

dynamodb = boto3.resource('dynamodb')
async_table = dynamodb.Table(os.environ['STATE_TABLE'])

projection_expression = "#i, #s"
expression_attributes_names = {"#i": "request_id", "#s": "state"}

query_parameters = {
        'ProjectionExpression': projection_expression,
        'ExpressionAttributeNames': expression_attributes_names
    }

start_timeout_retries = 300
    
def get_from_dynamo(table, query_parameters):

    response = table.get_item(**query_parameters)
    logger.info(f'Response:{response}')
    
    validate_response(response)
    records = response.get('Item')

    return records

def status_ecs(event):
    
    task_id = event['run_async_id']['task_id']
    
    response = ecs_client.describe_tasks(
        cluster=cluster_name,
        tasks=[task_id])
        
    logger.info(f'response received from task: {response}')
    
    status = response['tasks'][0]['lastStatus']
    task_status = event.get('run_async_status',{'task_status': []})['task_status']
    logger.info(f'Task status: {task_status}')
    logger.info(f'Status: {status}')
        
    task_status.append(status)
    logger.info(f'After Status: {task_status}')
    
    exit_code = response['tasks'][0]['containers'][0].get('exitCode',-1)
    logger.info(f'ExitCode:{exit_code}')
    
    if exit_code > 0 and status == 'STOPPED':
        raise ValueError('Container failed executing Python code. Check Cloudwatch LogGroup.')
        
    stop_code = response['tasks'][0].get('stopCode', '')
    
    if stop_code not in ['', 'EssentialContainerExited']:
        raise ValueError(f'Container failed with StopCode: {stop_code}')
        
    return status, task_status, exit_code, False
    
def status_lambda(event):
    
    task_id = event['run_async_id']['task_id']
    
    query_parameters['Key'] = {'request_id': task_id}
    record = get_from_dynamo(async_table, query_parameters)
    
    logger.info(f'Records: {record}')
    
    status = record['state']
    #status = 'STOPPED'
    task_status = event.get('run_async_status',{'task_status': []})['task_status']
    start_timeout = event.get('run_async_status',{'start_timeout': True})['start_timeout']
    
    logger.info(f'Task Status: {task_status}')
    logger.info(f'Status: {status}')
    logger.info(f'Start Timeout: {start_timeout}')
    
    if start_timeout:
        if (status == 'STARTED') and (len(task_status) == start_timeout_retries):
            raise ValueError(f'Start Timeout for the lambda function:{task_id}')
        elif (status != 'STARTED'):
            start_timeout = False
    
    task_status.append(status)
    logger.info(f'After Status: {task_status}')
    exit_code = 0
    
    return status, task_status, exit_code, start_timeout
    
    
def validate_response(response):

    try:
        status = response.get('ResponseMetadata', {}).get('HTTPStatusCode')

        if status == 200:
            return None

    except Exception as e:
        logger.error(f'Error checking Dynamo response: {repr(e)}')
        raise e
        
    return None
    
def lambda_handler(event, context):
    
    logger.info(f"Event received: {event}")
    
    processing_engine = event['run_async_id']['processing_engine']
    
    if processing_engine == 'ecs':
        status, task_status, exit_code, start_timeout = status_ecs(event)
    elif processing_engine == 'lambda_function':
        status, task_status, exit_code, start_timeout = status_lambda(event)
    
    
    return {
        'exit_code': exit_code,
        'statusCode': 200,
        'status': status,
        'start_timeout': start_timeout,
        'task_status': task_status
    }
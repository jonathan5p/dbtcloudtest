import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])
async_table = dynamodb.Table(os.environ['STATE_TABLE'])

ecs_client = boto3.client('ecs')
cluster_name = os.environ['ECS_CLUSTER']
task_definition = os.environ['TASK_DEFINITION']
subnet_ids = os.environ['ECS_SUBNETS']
function_name = os.environ['FUNCTION_NAME']

lambda_client = boto3.client('lambda')

def put_item(request_id, state, payload):
    response = async_table.put_item(
        Item={
            'request_id': request_id,
            'state': state,
            'payload': payload
        },
        ConditionExpression='attribute_not_exists(request_id)'
    )

    return response

def parse_event(event):
    
    task_args = []
    for item in event:
        task_args.append(f'--{item}')
        task_args.append(event[item])
        
    logger.info(f'Parsed args: {task_args}')
    return task_args
    
def run_ecs(event):
    
    task_arguments = parse_event(event['value'])
    
    response = ecs_client.run_task(
        cluster = cluster_name,
        launchType = 'FARGATE',
        taskDefinition = task_definition,
        startedBy = 'oidh-scheduler',
        networkConfiguration={
            'awsvpcConfiguration': {
            'subnets':subnet_ids.split(',')
            }
        },
        overrides = {
            'containerOverrides': [{
                'name': 'oidh-push',
                'command': ["python", "/app.py"] + task_arguments
            }]
        }
    )
    
    failures = response['failures']
    if len(failures) > 0:
        raise ValueError(f'Task start process failed: {failures}')

    task_arn = response['tasks'][0]['taskArn']
    task_id = task_arn.split("/")[-1]
    
    return task_id
    
def run_lambda(event):
    
    task_arguments = event['value']
    
    response = lambda_client.invoke(
        FunctionName=function_name,
        InvocationType='Event',
        Payload=json.dumps(task_arguments))
        
    request_id = response.get('ResponseMetadata', {}).get('RequestId')
    
    if response.get('StatusCode') in [200, 202] and request_id:
        response = put_item(request_id, 'STARTED', task_arguments)
        logger.info(f'Function {function_name} started with RequestId: {request_id}')
    else:
        logger.error(f'Something failed when calling {function_name}. Check {response}.')
        raise ValueError('Lambda call failed')

    return request_id
    

def lambda_handler(event, context):
    
    logger.info(f'Event received: {event}')
    processing_engine = 'lambda_function'
    
    id = event['value']['id']
    response = register_table.update_item(
        Key={'id': id},
        UpdateExpression="set #p=:p, #e=:e, #t=:t, #pe=:pe",
        ExpressionAttributeValues={':p': 'IN_PROGRESS', ':e': '', ':t':'', ':pe': processing_engine},
        ExpressionAttributeNames={"#p": "status", "#e": "error", "#t":"task_id", "#pe": "processing_engine"},
        ReturnValues="UPDATED_NEW")

    logger.info(f'Response from updates: {response}')
    
    if processing_engine == 'ecs':
        task_id = run_ecs(event)
    elif processing_engine == 'lambda_function':
        task_id = run_lambda(event)
    
    logger.info(f'Task initiatted with task_id: {task_id}')

    response = register_table.update_item(
        Key={'id': id},
        UpdateExpression="set #t=:t, #pe=:pe",
        ExpressionAttributeValues={':t': task_id, ':pe': processing_engine},
        ExpressionAttributeNames={"#t": "task_id", "#pe": "processing_engine"},
        ReturnValues="UPDATED_NEW")

    return {
        'statusCode': 200,
        'task_id': task_id,
        'processing_engine': processing_engine
    }
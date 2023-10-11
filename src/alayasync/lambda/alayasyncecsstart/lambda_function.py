import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

ecs_client = boto3.client('ecs')
cluster_name = os.environ['ECS_CLUSTER']
task_definition = os.environ['TASK_DEFINITION']
subnet_ids = os.environ['ECS_SUBNETS']

def parse_event(event):
    
    task_args = []
    for item in event:
        task_args.append(f'--{item}')
        task_args.append(event[item])
        
    logger.info(f'Parsed args: {task_args}')
    
    task_args = add_primary_key(task_args, event['table'])
    return task_args
    
def add_primary_key(task_args, table):
    
    task_args.append('--primary_key')
    task_args.append(os.environ[table.upper()])
    
    logger.info(f'Primary key: {os.environ[table.upper()]}')
    return task_args

def lambda_handler(event, context):
    
    logger.info(f'Event received: {event}')
    
    task_arguments = parse_event(event['value'])
    
    ids = event['value']['id'].split(',')
    
    logger.info(f'Updating ids:{ids}')
    
    for id in ids:
    
        response = register_table.update_item(
            Key={'id': id},
            UpdateExpression="set #p=:p, #e=:e, #t=:t, #r=:r",
            ExpressionAttributeValues={':p': 'IN_PROGRESS', ':e': '', ':t':'', ':r':{}},
            ExpressionAttributeNames={"#p": "status", "#e": "error", "#t":"task_id", "#r":"records"},
            ReturnValues="UPDATED_NEW")

        #logger.info(f'Response from updates: {response}')
    
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

    logger.info(f'Task initiatted with task_id: {task_id}')

    for id in ids:
    
        response = register_table.update_item(
            Key={'id': id},
            UpdateExpression="set #t=:t",
            ExpressionAttributeValues={':t': task_id},
            ExpressionAttributeNames={"#t": "task_id"},
            ReturnValues="UPDATED_NEW")

    return {
        'statusCode': 200,
        'task_id': task_id
    }
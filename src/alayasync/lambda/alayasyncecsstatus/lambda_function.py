import boto3
import json
import os

ecs_client = boto3.client('ecs')

cluster_name = os.environ['ECS_CLUSTER']

def lambda_handler(event, context):
    
    print(f"Event received: {event}")
    
    task_id = event['run_async_id']['task_id']
    
    response = ecs_client.describe_tasks(
        cluster=cluster_name,
        tasks=[task_id])
        
    print(f'response received from task: {response}')
    
    status = response['tasks'][0]['lastStatus']
    task_status = event.get('run_async_status',{'task_status': []})['task_status']
    print(f'Task status: {task_status}')
    print(f'Status: {status}')
        
    task_status.append(status)
    print(f'After Status: {task_status}')
    
    exit_code = response['tasks'][0]['containers'][0].get('exitCode',-1)
    print(f'ExitCode:{exit_code}')
    
    if exit_code > 0 and status == 'STOPPED':
        raise ValueError('Container failed executing Python code. Check Cloudwatch LogGroup.')
        
    stop_code = response['tasks'][0].get('stopCode', '')
    
    if stop_code not in ['', 'EssentialContainerExited']:
        raise ValueError(f'Container failed with StopCode: {stop_code}')
    
    return {
        'statusCode': 200,
        'status': status,
        'task_status': task_status,
        'exit_code': exit_code
    }
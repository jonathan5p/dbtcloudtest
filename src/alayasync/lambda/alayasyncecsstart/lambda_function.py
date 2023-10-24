import boto3
import json
import logging
import time
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
register_table = dynamodb.Table(os.environ["OIDH_TABLE"])

lambda_client = boto3.client("lambda")
task_function = os.environ["OIDH_TASK_FUNCTION"]


def add_primary_key(task_args, table):
    task_args.append("--primary_key")
    task_args.append(os.environ[table.upper()])

    logger.info(f"Primary key: {os.environ[table.upper()]}")
    return task_args


def lambda_handler(event, context):
    logger.info(f"Event received: {event}")
    ids = event["value"]["ids"].split(",")
    logger.info(f"Updating ids:{ids}")

    for id in ids:
        response = register_table.update_item(
            Key={"id": id},
            UpdateExpression="set #p=:p, #e=:e, #t=:t, #h=:h",
            ExpressionAttributeValues={
                ":p": "IN_PROGRESS",
                ":e": "",
                ":t": "",
                ":r": "NO_SET",
            },
            ExpressionAttributeNames={
                "#p": "status",
                "#e": "error",
                "#t": "task_id",
                "#h": "hubid",
            },
            ReturnValues="UPDATED_NEW",
        )

        logger.info(f"Response from updates: {response}")

    response = lambda_client.invoke(
        FunctionName=task_function,
        InvocationType="RequestResponse",
        Payload=json.dumps(event),
    )

    logger.info(f"Lambda invoke response: {response}")

    # failures = response['failures']
    # if len(failures) > 0:
    #     raise ValueError(f'Task start process failed: {failures}')

    # task_arn = response['tasks'][0]['taskArn']
    # task_id = task_arn.split("/")[-1]

    # logger.info(f'Task initiatted with task_id: {task_id}')

    # for id in ids:

    #     response = register_table.update_item(
    #         Key={'id': id},
    #         UpdateExpression="set #t=:t",
    #         ExpressionAttributeValues={':t': task_id},
    #         ExpressionAttributeNames={"#t": "task_id"},
    #         ReturnValues="UPDATED_NEW")

    return {"statusCode": 200, "task_id": "dummy_task"}

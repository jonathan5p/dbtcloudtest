import boto3
import json
import logging
import os
import sys
import time
import traceback

from multiprocessing import Process, Pipe, Manager
from sync import alaya

logger = logging.getLogger()
logger.setLevel('INFO')

STATE_TABLE = os.getenv('STATE_TABLE')
TIMEOUT = os.getenv('TIMEOUT')

dynamo_resource = boto3.resource('dynamodb')
table = dynamo_resource.Table(STATE_TABLE)

def put_item(request_id, state, payload):
    response = table.put_item(
        Item={
            'request_id': request_id,
            'state': state,
            'payload': payload
        },
    )

    return response


def register_process(conn, timeout, request_id, event, main_response):
    # Process used to register information in the Amazon DynamoDB table.

    try:
        done = None

        # Wait until timeout seconds before continue.
        if conn.poll(timeout=int(timeout)):
            done = conn.recv()

        if done == 'FINISHED':
            logger.info('Received: main_process finished')
            state = 'STOPPED'
        elif done == 'FAILED':
            logger.info('Received: main_process failed')
            state = 'FAILED'
        else:
            state = 'TIMEOUT'
            logger.info(f'Timeout for main_process')

        response = put_item(request_id, state, event)
        logger.info(f'Dynamo response: {response}')

        # Send ack to main_process
        conn.send(done)

    except Exception as e:

        logger.error(traceback.format_exc())
        response = put_item(request_id, 'FAILED', event)
        error = f'Error executing register_process for:{request_id}. {repr(e)}'
        logger.error(error)
        logger.info('Registering error in table.')

    return None


def main_process(conn, request_id, event, main_response):
    response = {}

    try:
        logger.info('Starting main_process ...')
        logger.info('Starting logic in main_process ...')

        # TODO: place here the business/operations logic.
        alaya.transfer(event)

        logger.info('Finishing logic in main_process ...')
        conn.send('FINISHED')

        # receive from register_process the state register in Amazon DynamoDB
        done = conn.recv()
        if done:
            response['status'] = done
        else:
            response['status'] = 'TIMEOUT'

        main_response['response'] = response

        logger.info('register_process notified.')

    except Exception as e:

        conn.send('FAILED')
        response['status'] = 'FAILED'
        main_response['response'] = response

        error = f'Error executing main_process. RequestId: {request_id}. {repr(e)}'
        logger.error(error)
        logger.error(traceback.format_exc())

    return None

##################################################################################
##################################################################################


def lambda_handler(event, context):
    response = {}
    request_id = context.aws_request_id

    try:
        # connection channel between processes
        conn_1, conn_2 = Pipe()

        # shared dictionary
        manager = Manager()
        main_response = manager.dict()

        processes = []
        p = Process(target=main_process, args=(conn_2, request_id, event, main_response))
        processes.append(p)
        p.start()

        p = Process(target=register_process, args=(conn_1, TIMEOUT, request_id, event, main_response))
        processes.append(p)
        p.start()

        for item in processes:
            item.join()

        response = main_response['response']
        logger.info(f'Response obtained from main_process: {response}')
        logger.info('Lambda handler finished')

    except Exception as e:

        put_item(request_id, 'FAILED', event)
        error = f'Error executing lambda_handler. RequestId: {request_id}. {repr(e)}'
        logger.error(error)

    return response
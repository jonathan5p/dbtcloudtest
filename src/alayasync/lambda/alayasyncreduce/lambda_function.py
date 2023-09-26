import boto3
import json
import logging
import os

dynamodb = boto3.resource('dynamodb')
register_table = dynamodb.Table(os.environ['OIDH_TABLE'])

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

def read_from_s3(bucket, key):

    content_object = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = content_object['Body'].read().decode('utf-8')
    json_content = json.loads(file_content)
    
    return json_content

def get_results(results_files: dict, bucket, status):

    result_keys = results_files[status]

    if len(result_keys) > 0:

        file_keys = result_keys[0]['Key']
        logger.info(f'File Keys:{file_keys}')

        file_content = read_from_s3(bucket, file_keys)
        logger.info(f'Results obtained: {file_content}')

        for item in file_content:
            
            logger.info(f'File:{item["Input"]}')
            logger.info(f'File Status:{item["Status"]}')
            
            input_json = json.loads(item["Input"])
            
            try:
                cause_json = json.loads(item.get("Cause", '{"Cause": ""}'))
            except Exception as e:
                if type(item.get("Cause", 'Error reading field, check logs')) == str: 
                    error_message = item.get("Cause", 'Error reading field, check logs')
                else:
                    error_message = repr(e)
                
                cause_json = {
                    'errorMessage': error_message
                }
            
            status = item["Status"]
            
            payload = {
                'id': input_json['value']['id'],
                'status': status,
                'error': cause_json.get('errorMessage', '')
            }

            logger.info(f'Payload:{payload}')

            response = register_table.update_item(
                Key={'id': payload['id']},
                UpdateExpression="set #p=:p, #e=:er",
                ExpressionAttributeValues={':p': payload['status'], ':er': payload['error']},
                ExpressionAttributeNames={"#p": "status", "#e": "error"},
                ReturnValues="UPDATED_NEW")

    else:
        logger.info(f'No files in status:{status}')

    return None


def lambda_handler(event, context):
    
    try:
    
        if event.get('MapRunArn') and event.get('ResultWriterDetails'):
        
            write_details = event.get('ResultWriterDetails')
            bucket = write_details['Bucket']
            key = write_details['Key']
        
            file_content = read_from_s3(bucket, key)
            logger.info('Reduce results:')
            logger.info(file_content)

            get_results(file_content['ResultFiles'], bucket, 'SUCCEEDED')
            get_results(file_content['ResultFiles'], bucket, 'FAILED')
            get_results(file_content['ResultFiles'], bucket, 'PENDING')
    
        else:       
            raise ValueError('Error parsing result file')
    except Exception as e:
        
        logger.info(f'Failure in reduce function. {repr(e)}')
        raise e
        
    # TODO implement
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }

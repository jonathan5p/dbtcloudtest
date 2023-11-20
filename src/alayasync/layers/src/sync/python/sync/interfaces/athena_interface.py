import boto3
import os
import time

WAIT_TIME = 20

class AthenaInterface:

    def __init__(self):
        self.client = boto3.client('athena')
        self.bucket = os.environ['ATHENA_BUCKET']

    def execute_query(self, query, path):

        response = self.client.start_query_execution(
            QueryString=query,
            ResultConfiguration={
                'OutputLocation': f's3://{self.bucket}/{path}/',
            }
        )

        return response['QueryExecutionId']

    def get_query_state(self,id):

        response = self.client.get_query_execution(
            QueryExecutionId=id
        )

        return response['QueryExecution']['Status']['State']

    def run_query(self, query, path, message):

        try:
            query_id = self.execute_query(query, path)

            self.wait_on_query(query_id)
            print(f'Done with query {query_id}')

        except Exception as e:

            error = f'{message}: {repr(e)}'
            raise ValueError(f'Athena Query Failed. {error}')

        return query_id

    
    def wait_on_query(self, id):

        try:
        
            stop_states = ['SUCCEEDED']
            continue_states = ['QUEUED','RUNNING']
            failed_states = ['FAILED','CANCELLED']

            status = 'QUEUED'
        
            while status in continue_states:
                status = self.get_query_state(id)
                time.sleep(WAIT_TIME)
                print(f'Query ID: {id} Status: {status}')

            if status in failed_states:
                raise ValueError(f'Query with id: {id} failed')

        except Exception as e:

            raise ValueError(f'Failure waiting for query:{id}. Error: {repr(e)}')

        return status
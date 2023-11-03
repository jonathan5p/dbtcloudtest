import boto3
import os


class DynamoInterface:

    def __init__(self, variable):
        self.resource = boto3.resource('dynamodb')
        self.table = self.resource.Table(os.environ[variable])
    

    def update_item(self, query_parameters):
        
        response = self.table.update_item(**query_parameters)
        return None


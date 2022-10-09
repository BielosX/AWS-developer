import boto3
import json

client = boto3.client('lambda')


def handle(event, context):
    functions = list(map(lambda f: f['FunctionName'], client.list_functions()['Functions']))
    response = {
        'functions': functions
    }
    return {
        'statusCode': 200,
        'statusDescription': "200 OK",
        'isBase64Encoded': False,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(response)
    }

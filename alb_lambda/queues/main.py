import boto3
import json

client = boto3.client('sqs')


def handle(event, context):
    queues = client.list_queues()['QueueUrls']
    response = {
        'queues': queues
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

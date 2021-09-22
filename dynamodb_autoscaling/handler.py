import boto3
import os

client = boto3.client('dynamodb')

def read_data(table_name):
    try:
        response = client.get_item(
            TableName=table_name,
            Key={
                'user_id': {
                    'S': "test_user"
                }
            }
        )
    except Exception as e:
        print(e)

def write_data(table_name):
    try:
        client.put_item(
            TableName=table_name,
            Item={
                'user_id': {
                    'S': "test_user"
                },
                'user_name': {
                    'S': "Stefan"
                }
            }
        )
    except Exception as e:
        print(e)

def handle(event, context):
    table_name = os.environ['TABLE_NAME']
    action = event['action']
    times = event['times']
    if action == 'WRITE':
        for i in range(0,times):
            write_data(table_name)
    elif action == "READ":
        for i in range(0,times):
            read_data(table_name)
    else:
        print("no such action")
    return "OK"
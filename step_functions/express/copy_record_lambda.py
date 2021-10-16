import os
import boto3
import dateutil.parser as dp

client = boto3.client('dynamodb')

def handle(event, context):
    table_name = os.environ["BACKUP_TABLE"]
    print(event)
    for record in event:
        diff = record['diff']
        created = diff['created']['S']
        diff.pop('created', None)
        time_in_seconds = str(int(dp.parse(created).timestamp()))
        diff['created'] = {'N': time_in_seconds}
        print(diff)
        if record['action'] == 'REMOVE':
            print("Record will be removed.")
            client.delete_item(
                TableName=table_name,
                Key=diff
            )
        else:
            print("Record will be updated or created.")
            client.put_item(
                TableName=table_name,
                Item=diff
            )
    return {}
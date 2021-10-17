import boto3
import os
import json

client = boto3.client('stepfunctions')

def map_record(record):
    dynamodb = record['dynamodb']
    if 'NewImage' in dynamodb:
        return {'diff': dynamodb['NewImage'], 'action': record['eventName']}
    else:
        return {'diff': dynamodb['Keys'], 'action': record['eventName']}

def handle(event, context):
    state_machine_arn = os.environ['STATE_MACHINE_ARN']
    print(event)
    records = event['Records']
    payload = list(map(map_record, records))
    response = client.start_sync_execution(
        stateMachineArn=state_machine_arn,
        input=json.dumps(payload)
    )
    print("Step Function finished with status: {}".format(response['status']))
    return "Ok"
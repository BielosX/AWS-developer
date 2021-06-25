import boto3
import os

def handle(event, context):
    bucket_name = os.environ['BUCKET_NAME']
    client = boto3.client('s3')
    resp = client.get_object(
        Bucket=bucket_name,
        Key="test_file.txt"
    )
    return resp['Body'].read().decode('utf-8')
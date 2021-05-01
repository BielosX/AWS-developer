import redis
import os
import boto3
import base64
from botocore.exceptions import ClientError


def get_secret(secret_arn, region_name):
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_arn
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            raise e
    else:
        if 'SecretString' in get_secret_value_response:
            return get_secret_value_response['SecretString']
        else:
            return base64.b64decode(get_secret_value_response['SecretBinary'])


def handle(event, context):
    redis_url = os.environ['REDIS_URL']
    region = os.environ['REGION']
    secret_arn = os.environ['SECRET_ARN']
    secret = get_secret(secret_arn, region)
    client = redis.Redis(host=redis_url, port=6379, db=0, ssl=True, password=secret, username="default")
    client.set('foo', 'bar')
    val = client.get('foo')
    return val
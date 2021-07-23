import http.client
import argparse
import base64
import json
from urllib.parse import urlparse
import boto3
import hmac
import hashlib

cognito_idp_client = boto3.client('cognito-idp')

def get_identity_id(account_id, identity_pool_id, user_pool, token):
    body = {
        'AccountId': account_id,
        'IdentityPoolId': identity_pool_id,
        'Logins': {
            "cognito-idp.eu-west-1.amazonaws.com/{}".format(user_pool): token
        }
    }
    conn = http.client.HTTPSConnection("cognito-identity.eu-west-1.amazonaws.com", 443)
    conn.request('POST', "",
        headers={
            'Content-Type': 'application/x-amz-json-1.1',
            'x-amz-target': 'com.amazonaws.cognito.identity.model.AWSCognitoIdentityService.GetId'
        },
        body=json.dumps(body)
    )
    resp = conn.getresponse()
    data = resp.read()
    conn.close()
    return json.loads(data)['IdentityId']

def get_credentials(identity_id, user_pool, token):
    body = {
        'IdentityId': identity_id,
        'Logins': {
            "cognito-idp.eu-west-1.amazonaws.com/{}".format(user_pool): token
        }
    }
    conn = http.client.HTTPSConnection("cognito-identity.eu-west-1.amazonaws.com", 443)
    conn.request('POST', "",
        headers={
            'Content-Type': 'application/x-amz-json-1.1',
            'x-amz-target': 'com.amazonaws.cognito.identity.model.AWSCognitoIdentityService.GetCredentialsForIdentity'
        },
        body=json.dumps(body)
    )
    resp = conn.getresponse()
    data = resp.read()
    conn.close()
    return json.loads(data)['Credentials']

def get_token(client_id, user, password):
    response = cognito_idp_client.initiate_auth(
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": user,
            "PASSWORD": password
        },
        ClientId=client_id
    )
    return response['AuthenticationResult']['IdToken']

def send_message(queue_url, access_key_id, secret_key, session_token, message):
    sqs_client = boto3.client('sqs',
        aws_access_key_id=access_key_id,
        aws_secret_access_key=secret_key,
        aws_session_token=session_token
    )
    response = sqs_client.send_message(
        QueueUrl=queue_url,
        MessageBody=message,

    )
    return response['MessageId']


def main():
    parser = argparse.ArgumentParser(description='Sends message to SQS.')
    parser.add_argument('--url')
    parser.add_argument('--client-id')
    parser.add_argument('--user-pool')
    parser.add_argument('--account-id')
    parser.add_argument('--identity-pool-id')
    parser.add_argument('--user')
    parser.add_argument('--password')
    parser.add_argument('--queue-url')
    parser.add_argument('--message')
    args = vars(parser.parse_args())
    token = get_token(args['client_id'], args['user'], args['password'])
    user_pool = args['user_pool']
    identity_id = get_identity_id(args['account_id'], args['identity_pool_id'], user_pool, token)
    credentials = get_credentials(identity_id, user_pool, token)
    access_key_id = credentials['AccessKeyId']
    secret_key = credentials['SecretKey']
    session_token = credentials['SessionToken']
    message_id = send_message(args['queue_url'], access_key_id, secret_key, session_token, args['message'])
    print("Message ID: {}".format(message_id))

if __name__ == "__main__":
    main()
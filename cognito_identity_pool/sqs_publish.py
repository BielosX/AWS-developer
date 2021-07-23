import http.client
import argparse
import base64
import json

def get_identity_id(account_id, identity_pool_id, user_pool, token):
    body = {
        'AccountId': account_id,
        'IdentityPoolId': identity_pool_id,
        'Logins': {
            user_pool: token
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
    print(data)
    return json.loads(data)['IdentityId']

def get_token(url, client_id, client_secret):
    conn = http.client.HTTPSConnection(url, 443)
    basic = base64.b64encode('{}:{}'.format(client_id, client_secret).encode('ascii')).decode('ascii')
    conn.request('POST',
        '/oauth2/token?grant_type=client_credentials&scope=demo%2Ftest&client_id={}'.format(client_id),
        headers={
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': "Basic {}".format(basic)
        })
    resp = conn.getresponse()
    data = resp.read()
    conn.close()
    return json.loads(data)['access_token']

def main():
    parser = argparse.ArgumentParser(description='Sends message to SQS.')
    parser.add_argument('--url')
    parser.add_argument('--id')
    parser.add_argument('--secret')
    parser.add_argument('--user-pool')
    parser.add_argument('--account-id')
    parser.add_argument('--identity-pool-id')
    args = vars(parser.parse_args())
    token = get_token(args['url'], args['id'], args['secret'])
    identity_id = get_identity_id(args['account_id'], args['identity_pool_id'], args['user_pool'], token)
    print(identity_id)

if __name__ == "__main__":
    main()
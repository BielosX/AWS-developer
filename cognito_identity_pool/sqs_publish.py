import http.client
import argparse
import base64
import json

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
    args = vars(parser.parse_args())
    token = get_token(args['url'], args['id'], args['secret'])
    print(token)

if __name__ == "__main__":
    main()
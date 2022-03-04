import json
import redis
import re
import random
import sys
import os

def response(status_code, content):
    return {
        "statusCode": status_code,
        "body": json.dumps(content),
    }


def lambda_handler(event, context):
    host = os.environ['REDIS_URL']
    port = os.environ['REDIS_PORT']
    redis_client = redis.Redis(host=host, port=port, db=0)
    if event['httpMethod'] == 'GET':
        match = re.search("/users/(\d*)", event['path'])
        id = int(match.group(1))
        value = json.loads(redis_client.get(id))
        value['id'] = id
        return response(200, value)
    if event['httpMethod'] == 'POST':
        value = event['body']
        id = random.randrange(sys.maxsize)
        redis_client.set(id, value)
        resp = json.loads(value)
        resp['id'] = id
        return response(200, resp)
    return response(404, "Not found")

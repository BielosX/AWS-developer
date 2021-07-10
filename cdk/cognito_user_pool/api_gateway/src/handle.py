import json
import os

def handle(event, context):
    url = os.environ["URL"]
    return {
        "statusCode": 302,
        "headers": {
            "Location": url,
        },
        "body": ""
    }
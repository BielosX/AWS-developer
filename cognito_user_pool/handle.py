import json
import base64

def handle(event, context):
    token = event['headers']['Authorization']
    print(token)
    body = token.split('.')[1] + '=='
    content = json.loads(base64.urlsafe_b64decode(body))
    user_name = content['cognito:username']
    email = content['email']
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({
            "email": email,
            "username": user_name
        }, indent=4)
    }

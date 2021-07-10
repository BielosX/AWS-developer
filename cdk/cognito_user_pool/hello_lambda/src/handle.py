import boto3
import json

def handle(event, context):
    #client = boto3.client('cognito-idp')
    #token = split(event['headers']['Authorization'])[1]
    #user = client.get_user(AccessToken=token)
    #user_attributes = user['UserAttributes']
    #user_name = user_attributes['username']
    #email = user_attributes['email']
    #favorite_fruit = ['favorite_fruit']
    #return {
    #    "statusCode": "200",
    #    "body": """ <h3>Username: {}</h3>
    #                <h3>Email: {}</h3>
    #                <h3>Favorite fruit: {}</h3>""".format(user_name, email, favorite_fruit)
    #}
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(event, indent=4)
    }
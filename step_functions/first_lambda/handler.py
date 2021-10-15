import json

def handle(event, context):
    print(event)
    return json.dumps({
        'result': "Hello"
    })
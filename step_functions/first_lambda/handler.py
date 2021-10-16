import json

def handle(event, context):
    print(event)
    return {
        'result': "Hello from First Lambda"
    }
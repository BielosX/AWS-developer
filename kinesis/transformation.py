import base64

def transform(record):
    data = record['data'].encode('ascii')
    message_bytes = base64.b64decode(data)
    message = message_bytes.decode('ascii')
    final_message = "Hello from Transformation Lambda. {}".format(message)
    return {
        'recordId': record['recordId'],
        'result': 'Ok',
        'data': base64.b64encode(final_message.encode('ascii')).decode('ascii')
    }

def handle(event, context):
    print(event)
    records = event['records']
    output = map(transform, records)
    return { 'records': list(output) }
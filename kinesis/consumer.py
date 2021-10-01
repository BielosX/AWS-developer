import base64

def handle(event, context):
    records = event['Records']
    for record in records:
        print(record)
        data = record['kinesis']['data'].encode('ascii')
        message_bytes = base64.b64decode(data)
        message = message_bytes.decode('ascii')
        print(message)
    return {}
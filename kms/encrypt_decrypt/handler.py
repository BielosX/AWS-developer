import boto3
import os
import base64

client = boto3.client('kms')

def encrypt(value, key_id):
    response = client.encrypt(
        KeyId = key_id,
        Plaintext = value.encode('utf-8')
    )
    return base64.b64encode(response['CiphertextBlob']).decode('ascii')

def decrypt(cipher, key_id):
    response = client.decrypt(
        KeyId = key_id,
        CiphertextBlob = base64.b64decode(cipher)
    )
    return response['Plaintext'].decode('utf-8')

func = {
    "ENCRYPT": encrypt,
    "DECRYPT": decrypt
}

def handle(event, context):
    key_id = os.environ['KEY_ID']
    operation = func[event['Operation']]
    value = event['Value']
    return operation(value, key_id)
from flask import Flask
from flask import request
import boto3
import json
import os

app = Flask(__name__)

worker_queue_url = os.environ['WORKER_QUEUE_URL']

client = boto3.client('sqs', region_name="eu-west-1")

@app.route("/messages", methods=["POST"])
def messages():
    body = request.get_json()
    print("Received payload: {}".format(body))
    body_str = json.dumps(body)
    client.send_message(
        QueueUrl=worker_queue_url,
        MessageBody=body_str
    )
    return "Ok"

@app.route("/appstatus/health", methods=["GET"])
def health():
    return "Ok"

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000)
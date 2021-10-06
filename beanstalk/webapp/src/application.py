from flask import Flask
from flask import request
import boto3
import json
import os
import http.client

def get_instance_id():
    conn = http.client.HTTPConnection("169.254.169.254", 80)
    conn.request("GET", "/latest/meta-data/instance-id")
    resp = conn.getresponse()
    content = resp.read()
    conn.close()
    return content.decode('ascii')

app = Flask(__name__)

worker_queue_url = os.environ['WORKER_QUEUE_URL']

client = boto3.client('sqs', region_name="eu-west-1")

instance_id = get_instance_id()

@app.route("/messages", methods=["POST"])
def messages():
    body = request.get_json()
    print("Received payload: {}".format(body), flush=True)
    body_str = json.dumps(body)
    client.send_message(
        QueueUrl=worker_queue_url,
        MessageBody=body_str
    )
    ip = request.headers.get('X-Forwarded-For')
    return "Ok from {}. Requested by {}".format(instance_id, ip)

@app.route("/appstatus/health", methods=["GET"])
def health():
    ip = request.headers.get('X-Forwarded-For')
    return "Ok from {}. Requested by {}".format(instance_id, ip)

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000)
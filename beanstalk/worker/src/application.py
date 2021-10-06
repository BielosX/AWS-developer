from flask import Flask
from flask import request

app = Flask(__name__)

@app.route("/handle", methods=["POST"])
def handle():
    body = request.get_json()
    print(body)
    return "Ok"

@app.route("/cron", methods=["POST"])
def cron():
    print("Triggered by Cron")
    return "Ok"

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000)
from flask import Flask
from flask import request

app = Flask(__name__)

@app.route("/handle", methods=["POST"])
def handle():
    body = request.get_json()
    print(body)
    return "Ok"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
from flask import Flask

application = Flask(__name__)


@application.route("/status/health")
def health():
    return "Ok"


@application.route("/hello")
def hello():
    print("Hello", flush=True)
    return "hello"


@application.route("/error")
def error():
    application.logger.error("Problem occurred")
    return "Error", 500

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


@application.route("/superlog")
def superlog():
    for x in range(0, 10000):
        application.logger.error("Hello {}".format(x))
    return "Ok"

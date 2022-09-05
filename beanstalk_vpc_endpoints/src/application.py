from flask import Flask

application = Flask(__name__)


@application.route("/health")
def health():
    return "Ok"

from python:3.8-alpine
RUN apk update && \
    apk add ansible && \
    apk add py3-boto3 && \
    ansible-galaxy collection install amazon.aws
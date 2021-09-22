#!/bin/bash

ACTION=$1
INVOCATIONS=$2

lambda_write() {
    aws lambda invoke --function-name dynamodb-demo-lambda \
      --invocation-type Event --payload "$(printf '{"action": "WRITE", "times": %u}' "$INVOCATIONS")" \
      --region eu-west-1 \
      --cli-binary-format raw-in-base64-out \
      --no-cli-pager \
      /dev/null > /dev/null
}

lambda_read() {
    aws lambda invoke --function-name dynamodb-demo-lambda \
      --invocation-type Event --payload "$(printf '{"action": "READ", "times": %u}' "$INVOCATIONS")" \
      --region eu-west-1 \
      --cli-binary-format raw-in-base64-out \
      --no-cli-pager \
      /dev/null > /dev/null
}

case $ACTION in
  "read") lambda_read ;;
  "write") lambda_write ;;
  *) echo "read or write";;
esac
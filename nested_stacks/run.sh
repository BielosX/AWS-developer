#!/bin/bash

destroy() {
    aws cloudformation delete-stack --stack-name main-stack
    aws cloudformation wait stack-delete-complete --stack-name main-stack
    BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name deployment-bucket | jq -r '.Stacks[0].Outputs[0].OutputValue')
    aws s3 rm --recursive "s3://$BUCKET_NAME"
    aws cloudformation delete-stack --stack-name deployment-bucket
    aws cloudformation wait stack-delete-complete --stack-name deployment-bucket
}

deploy() {
    aws cloudformation deploy --template-file ./bucket.yaml --stack-name deployment-bucket
    BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name deployment-bucket | jq -r '.Stacks[0].Outputs[0].OutputValue')
    echo "$BUCKET_NAME"
    aws s3 cp stacks "s3://$BUCKET_NAME/" --recursive
    aws cloudformation deploy --template-file ./main.yaml \
        --stack-name main-stack \
        --parameter-overrides "DeploymentBucket"="$BUCKET_NAME"
}

case "$1" in
    "deploy") deploy ;;
    "destroy") destroy ;;
    *) echo "deploy or destroy" ;;
esac

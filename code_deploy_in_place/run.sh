#!/bin/bash

export AWS_PAGER=""

function connect() {
  INSTANCE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=code-deploy-in-place-demo \
    Name=instance-state-name,Values=running \
    | jq -r '.Reservations[0].Instances[0].InstanceId')
  PUBLIC_IP=$(aws ec2 describe-instances --filters Name=tag:Name,Values=code-deploy-in-place-demo \
   Name=instance-state-name,Values=running | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
  ssh-keygen -t rsa -f ec2_key -P ""
  aws ec2-instance-connect send-ssh-public-key \
      --instance-id "$INSTANCE_ID" \
      --availability-zone eu-west-1a \
      --instance-os-user ec2-user \
      --ssh-public-key file://ec2_key.pub

  ssh -o "IdentitiesOnly=yes" -i ec2_key "ec2-user@$PUBLIC_IP"
}

function deploy() {
  ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")
  BUCKET="code-deploy-in-place-demo-${ACCOUNT_ID}-eu-west-1"
  aws s3 cp build/app.zip "s3://${BUCKET}/"
  aws deploy create-deployment --application-name "demo-app" \
    --deployment-group-name "demo-app-group" \
    --s3-location bucket="$BUCKET",bundleType=zip,key=app.zip
}

case "$1" in
  "connect") connect ;;
  "deploy") deploy ;;
  *) echo "Commands: connect|deploy" ;;
esac
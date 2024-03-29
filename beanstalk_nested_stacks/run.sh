#!/bin/bash

BUCKETS_STACK_NAME="app-buckets"
APP_STACK_NAME="app-stack"
APP_NAME="my-app"

init_buckets() {
  aws cloudformation deploy --template-file infra/app-buckets.yaml --stack-name "$BUCKETS_STACK_NAME"
}

artifacts_bucket() {
  EXPORT_NAME="${BUCKETS_STACK_NAME}-Artifacts-Bucket-Name"
  ARTIFACTS_BUCKET=$(aws cloudformation list-exports | \
    jq --arg NAME "$EXPORT_NAME" -r '.Exports[] | select(.Name == $NAME) | .Value')
}

templates_bucket() {
  EXPORT_NAME="${BUCKETS_STACK_NAME}-Templates-Bucket-Name"
  TEMPLATES_BUCKET=$(aws cloudformation list-exports | \
    jq --arg NAME "$EXPORT_NAME" -r '.Exports[] | select(.Name == $NAME) | .Value')
}

deploy_artifact() {
  TIMESTAMP=$(date +%s)
  mvn clean
  mvn clean verify -Dtimestamp="$TIMESTAMP"
  artifacts_bucket
  JAR_FILE="app-${TIMESTAMP}.jar"
  cp target/beanstalk_nested_stacks-1.0-SNAPSHOT.jar target/"$JAR_FILE"
  aws s3 cp target/"$JAR_FILE" "s3://${ARTIFACTS_BUCKET}"
}

get_cert_arn() {
  ARNS=$(aws acm list-certificates --includes keyTypes=RSA_4096 | jq -c '.CertificateSummaryList | map(.CertificateArn) | .[]')
  RESULT=""
  for arn in $ARNS
  do
    TRIMMED=$(echo "$arn" | tr -d '"')
    TAG=$(aws acm list-tags-for-certificate --certificate-arn "$TRIMMED" | jq -r '.Tags | map(.Value) | .[] | select(test("self-signed-test-cert"))')
    if [ "$TAG" = 'self-signed-test-cert' ]; then
      RESULT=$TRIMMED
    fi
  done
}

import_cert() {
  get_cert_arn
  if [ -z "$RESULT" ]; then
    mkdir -p "$PWD/out"
    openssl req -newkey rsa:4096 \
                -x509 \
                -sha256 \
                -days 365 \
                -nodes \
                -out "$PWD/out/cert.crt" \
                -keyout "$PWD/out/private.key" \
                -subj "/C=us/ST=washington/L=seattle/O=example/OU=example/CN=example.com"
    sleep 30
    CERTIFICATE_ARN=$(aws acm import-certificate --certificate "fileb://$PWD/out/cert.crt" \
      --private-key "fileb://$PWD/out/private.key" \
      --tags Key=Name,Value="self-signed-test-cert" | jq -r '.CertificateArn')
    echo "Certificate imported, ARN: $CERTIFICATE_ARN"
    rm -rf "$PWD/out"
  else
    TRIMMED=$(echo "$RESULT" | tr -d '"')
    echo "Certificate already exist with ARN: $TRIMMED"
    CERTIFICATE_ARN="$TRIMMED"
  fi
}

deploy_templates() {
  templates_bucket
  artifacts_bucket
  import_cert
  aws s3 cp infra/templates "s3://$TEMPLATES_BUCKET" --recursive
  aws cloudformation deploy --template-file infra/main.yaml --stack-name "$APP_STACK_NAME" \
    --parameter-overrides TemplatesBucketName="$TEMPLATES_BUCKET" DeploymentBucket="$ARTIFACTS_BUCKET" \
    ArtifactS3Key="$JAR_FILE" AppName="$APP_NAME" \
    CertificateArn="$CERTIFICATE_ARN" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
}

clean_buckets() {
  artifacts_bucket
  templates_bucket
  aws s3 rm "s3://$TEMPLATES_BUCKET" --recursive
  aws s3 rm "s3://$ARTIFACTS_BUCKET" --recursive
}

deploy() {
  init_buckets
  deploy_artifact
  deploy_templates
}

destroy() {
  clean_buckets
  aws cloudformation delete-stack --stack-name "$APP_STACK_NAME"
  aws cloudformation wait stack-delete-complete --stack-name "$APP_STACK_NAME"
  aws cloudformation delete-stack --stack-name "$BUCKETS_STACK_NAME"
  aws cloudformation wait stack-delete-complete --stack-name "$BUCKETS_STACK_NAME"
  get_cert_arn
  if [ -n "$RESULT" ]; then
    aws acm delete-certificate --certificate-arn "$RESULT"
  fi
}

purge_db() {
  BUCKET=$(aws s3api list-buckets --query "Buckets[].Name" | jq -r '.[] | select(test("app-users-*"))')
  echo "DB bucket: $BUCKET"
  aws s3 rm "s3://$BUCKET" --recursive
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "purge_db") purge_db ;;
  *) echo "Hello"
esac

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

deploy_templates() {
  templates_bucket
  artifacts_bucket
  aws s3 cp infra/templates "s3://$TEMPLATES_BUCKET" --recursive
  aws cloudformation deploy --template-file infra/main.yaml --stack-name "$APP_STACK_NAME" \
    --parameter-overrides TemplatesBucketName="$TEMPLATES_BUCKET" DeploymentBucket="$ARTIFACTS_BUCKET" \
    ArtifactS3Key="$JAR_FILE" AppName="$APP_NAME" \
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
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  *) echo "Hello"
esac

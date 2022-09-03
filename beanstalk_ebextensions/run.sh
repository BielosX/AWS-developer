#!/bin/bash

export AWS_PAGER=""

function package() {
  rm -f latest.zip
  zip -r -j latest.zip src
  zip -u latest.zip requirements.txt
  zip -ur latest.zip .ebextensions
}

function deploy() {
    ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
    REGION=$(aws configure get region)
    BUCKET_NAME="demo-app-bucket-${REGION}-${ACCOUNT_ID}"
    TIMESTAMP=$(date +%s)
    LABEL="app-${TIMESTAMP}"
    FILE_NAME="${LABEL}.zip"
    aws s3 cp latest.zip "s3://${BUCKET_NAME}/${FILE_NAME}"
    aws elasticbeanstalk create-application-version --application-name "demo-app" \
      --version-label "${LABEL}" \
      --source-bundle S3Bucket="${BUCKET_NAME}",S3Key="${FILE_NAME}"
    aws elasticbeanstalk update-environment --application-name "demo-app" \
      --environment-name "demo-app-env" \
      --version-label "${LABEL}"
}

function terraform_apply() {
  pushd terraform || exit
  terraform init && terraform apply -auto-approve
  popd || exit
}

function terraform_plan() {
  pushd terraform || exit
  terraform plan
  popd || exit
}

function terraform_destroy() {
  pushd terraform || exit
  terraform destroy -auto-approve || exit
  popd || exit
}

function cf_apply() {
  # Returns a list of the available solution stack names, with the public version first and then in reverse chronological order.
  SOLUTION_STACK=$(aws elasticbeanstalk list-available-solution-stacks \
    | jq -r '.SolutionStacks | map(select(test("64bit Amazon Linux 2 (.*) running Python 3.8"))) | .[0]')
  aws cloudformation deploy --template-file cloudformation/beanstalk.yaml \
    --stack-name "demo-app-stack" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameter-overrides SolutionStackName="${SOLUTION_STACK}"
}

function cf_destroy() {
  ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
  REGION=$(aws configure get region)
  BUCKET_NAME="demo-app-bucket-${REGION}-${ACCOUNT_ID}"
  aws s3 rm "s3://${BUCKET_NAME}" --recursive
  aws cloudformation delete-stack --stack-name "demo-app-stack"
  aws cloudformation wait stack-delete-complete --stack-name "demo-app-stack"
}

case "$1" in
  "package") package ;;
  "deploy") deploy ;;
  "terraform_apply") terraform_apply ;;
  "terraform_plan") terraform_plan ;;
  "terraform_destroy") terraform_destroy ;;
  "cf_apply") cf_apply ;;
  "cf_destroy") cf_destroy ;;
  *) echo "package | deploy | terraform_apply | terraform_plan | terraform_destroy | cf_apply | cf_destroy" ;;
esac

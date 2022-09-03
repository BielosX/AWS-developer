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
  terraform destroy -auto-approve
  popd || exit
}

case "$1" in
  "package") package ;;
  "deploy") deploy ;;
  "terraform_apply") terraform_apply ;;
  "terraform_plan") terraform_plan ;;
  "terraform_destroy") terraform_destroy ;;
  *) echo "package | deploy | terraform_apply | terraform_plan | terraform_destroy" ;;
esac

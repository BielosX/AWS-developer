#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""

# it's not 64bit Amazon Linux 2 v3.4.1 running Python 3.8
PLATFORM_BRANCH_NAME="Python 3.8 running on 64bit Amazon Linux 2"

function get_platform_ami() {
  platform_arn=$(aws elasticbeanstalk list-platform-versions \
    --filters Type=PlatformBranchName,Operator=contains,Values="$PLATFORM_BRANCH_NAME" \
    | jq -r '.PlatformSummaryList[0].PlatformArn')
  ami=$(aws elasticbeanstalk describe-platform-version \
        --platform-arn "$platform_arn" \
        --query PlatformDescription.CustomAmiList | jq -r '.[] | select(.VirtualizationType=="hvm") | .ImageId')
}

function get_image_name() {
  get_platform_ami
  aws ec2 describe-images --image-ids "$ami" | jq -r '.Images[0].Name'
}

function remove_images() {
  images=$(aws ec2 describe-images --filters "Name=tag:Name,Values=python3-custom-image")
  for k in $(echo "$images" | jq -r '.Images | keys | .[]'); do
    image=$(echo "$images" | jq -r ".Images[$k]")
    image_id=$(echo "$image" | jq -r '.ImageId')
    mapping_keys=$(echo "$image" | jq -r '.BlockDeviceMappings | keys | .[]')
    snapshot_ids=$(echo "$image" | jq -r '.BlockDeviceMappings | map(.Ebs.SnapshotId)')
    echo "Deleting AMI $image_id"
    aws ec2 deregister-image --image-id "$image_id"
    for id in $mapping_keys; do
      snapshot_id=$(echo "$snapshot_ids" | jq -r ".[$id]")
      echo "Deleting snapshot $snapshot_id"
      aws ec2 delete-snapshot --snapshot-id "$snapshot_id"
    done
  done
}

function build_image() {
  pushd image || exit
  packer build .
  popd || exit
}

function deploy() {
    pushd infra || exit
    terraform init && terraform apply -auto-approve
    popd || exit
}

function destroy() {
    pushd infra || exit
    terraform destroy -auto-approve
    popd || exit
}

case "$1" in
  "platform-ami") get_platform_ami ; echo "$ami" ;;
  "image-name") get_image_name ;;
  "remove-images") remove_images ;;
  "image") build_image ;;
  "deploy") deploy ;;
  "destroy") destroy ;;
esac
provider "aws" {
  region = "eu-west-1"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  instance_name = "code-deploy-in-place-demo"
}

data "aws_ami" "amazon-linux-2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "demo_security_group" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "demo_role" {
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}

resource "aws_iam_instance_profile" "demo_instance_profile" {
  role = aws_iam_role.demo_role.id
}

resource "aws_instance" "demo_instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  associate_public_ip_address = true
  availability_zone = "eu-west-1a"
  security_groups = [aws_security_group.demo_security_group.name]
  iam_instance_profile = aws_iam_instance_profile.demo_instance_profile.id
  user_data = file("${path.module}/init.sh")
  tags = {
    Name = local.instance_name
  }
}

resource "aws_s3_bucket" "deployment_bucket" {
  bucket = "code-deploy-in-place-demo-${local.account_id}-eu-west-1"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "deployment_bucket_acl" {
  bucket = aws_s3_bucket.deployment_bucket.id
  acl = "private"
}

resource "aws_codedeploy_app" "demo_app" {
  name = "demo-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_config" "demo_app_config" {
  deployment_config_name = "demo-app-config"
  compute_platform = "Server"
  minimum_healthy_hosts {
    type = "HOST_COUNT"
    value = 0
  }
}

data "aws_iam_policy_document" "code_deploy_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["codedeploy.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "code_deploy_role" {
  assume_role_policy = data.aws_iam_policy_document.code_deploy_assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"]
}

resource "aws_codedeploy_deployment_group" "demo_app_group" {
  app_name = aws_codedeploy_app.demo_app.name
  deployment_group_name = "demo-app-group"
  service_role_arn = aws_iam_role.code_deploy_role.arn
  deployment_config_name = aws_codedeploy_deployment_config.demo_app_config.deployment_config_name
  ec2_tag_set {
    ec2_tag_filter {
      key = "Name"
      value = local.instance_name
      type = "KEY_AND_VALUE"
    }
  }
}
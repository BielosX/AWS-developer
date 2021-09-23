provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source = "./vpc"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "demo-bucket" {
  bucket = "iam-demo-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = true
  acl = "private"
}

resource "aws_security_group" "demo-security-group" {
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
}

resource "aws_eip" "demo-eip" {
  vpc = true
}

data "aws_iam_policy_document" "ec2-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}
locals {
  allowed_tag = "S3AccessAllowed"
}

data "aws_iam_policy_document" "ec2-s3-bucket-access" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.demo-bucket.arn]
    condition {
      test     = "StringLike"
      values   = ["$${aws:SourceIp}/*"]
      variable = "s3:prefix"
    }
    condition {
      test     = "IpAddress"
      values   = [aws_eip.demo-eip.public_ip]
      variable = "aws:SourceIp"
    }
    condition {
      test     = "StringEquals"
      values   = ["YES"]
      variable = "aws:PrincipalTag/${local.allowed_tag}"
    }
  }
  statement {
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.demo-bucket.arn}/$${aws:SourceIp}/*"]
    condition {
      test     = "IpAddress"
      values   = [aws_eip.demo-eip.public_ip]
      variable = "aws:SourceIp"
    }
    condition {
      test     = "StringEquals"
      values   = ["YES"]
      variable = "aws:PrincipalTag/${local.allowed_tag}"
    }
  }
}

resource "aws_iam_role" "demo-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  inline_policy {
    name = "DemoPolicy"
    policy = data.aws_iam_policy_document.ec2-s3-bucket-access.json
  }
  tags = {
    (local.allowed_tag) = "YES"
  }
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

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.demo-role.name
}

resource "aws_instance" "demo-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  subnet_id = module.vpc.public_subnet_id
  associate_public_ip_address = true
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.demo-security-group.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.name
}

resource "aws_eip_association" "ec2-eip-assoc" {
  allocation_id = aws_eip.demo-eip.id
  instance_id = aws_instance.demo-instance.id
}
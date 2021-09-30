provider "aws" {
  region = "eu-west-1"
}

resource "aws_iam_user" "test-user" {
  name = "test-user"
  force_destroy = true
}

resource "aws_iam_access_key" "test-user-access-key" {
  user = aws_iam_user.test-user.name
  status = "Active"
}

resource "aws_ssm_parameter" "test-user-secret" {
  name  = "test-user-secret"
  type  = "String"
  value = aws_iam_access_key.test-user-access-key.secret
}

resource "aws_ssm_parameter" "test-user-access-key-param" {
  name  = "test-user-access-key"
  type  = "String"
  value = aws_iam_access_key.test-user-access-key.id
}

data "aws_iam_policy_document" "test-user-role-assume-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = [aws_iam_user.test-user.arn]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      values   = [var.source_ip]
      variable = "aws:SourceIp"
    }
  }
}

resource "aws_iam_role" "test-user-role" {
  name = "test-user-role"
  assume_role_policy = data.aws_iam_policy_document.test-user-role-assume-policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}
locals {
  region = "eu-west-1"
}

provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_use_kms" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  }
}

resource "aws_iam_policy" "lambda_use_kms" {
  policy = data.aws_iam_policy_document.lambda_use_kms.json
}

resource "aws_iam_role_policy_attachment" "lambda_use_kms_attach" {
  policy_arn = aws_iam_policy.lambda_use_kms.arn
  role = aws_iam_role.lambda_role.id
}

data "aws_iam_policy_document" "key_policy" {
  statement {
    sid = "Allow ROOT to manage key"
    effect = "Allow"
    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type = "AWS"
    }
    actions = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid = "Allow Lambda role to use key"
    effect = "Allow"
    principals {
      identifiers = [aws_iam_role.lambda_role.arn]
      type = "AWS"
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "lambda_key" {
  key_usage = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled = true
  policy = data.aws_iam_policy_document.key_policy.json
}

data "archive_file" "archive_lambda_code" {
  output_path = "${path.module}/handler.zip"
  source_file = "${path.module}/handler.py"
  type = "zip"
}

resource "aws_lambda_function" "encryption_lambda" {
  function_name = "encryption_lambda"
  handler = "handler.handle"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  memory_size = 512
  timeout = 60
  filename = data.archive_file.archive_lambda_code.output_path
  source_code_hash = filebase64sha256(data.archive_file.archive_lambda_code.output_path)
  environment {
    variables = {
      KEY_ID: aws_kms_key.lambda_key.key_id
    }
  }
}
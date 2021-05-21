data "aws_region" "current" {}

locals {
  zip_file = "${path.module}/test_lambda.zip"
  redis_file = "${path.module}/redis.zip"
}

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

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role = aws_iam_role.lambda_role.id
}

data "aws_iam_policy_document" "get_secret" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "get_secret" {
  policy = data.aws_iam_policy_document.get_secret.json
  role = aws_iam_role.lambda_role.id
}

resource "aws_security_group" "lambda_sg" {
  vpc_id = var.vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 6379
    protocol = "tcp"
    to_port = 6379
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    protocol = "tcp"
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    protocol = "tcp"
    to_port = 443
  }
}

resource "aws_lambda_layer_version" "redis_lambda_layer" {
  layer_name = "redis_lambda_layer"
  filename = local.redis_file
  source_code_hash = filebase64sha256(local.redis_file)
  compatible_runtimes = ["python3.8"]
}

resource "aws_lambda_function" "test_lambda" {
  function_name = "test_function"
  handler = "handler.handle"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  filename = local.zip_file
  source_code_hash = filebase64sha256(local.zip_file)
  memory_size = 512
  timeout = 60
  layers = [aws_lambda_layer_version.redis_lambda_layer.arn]
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids = [var.private_subnet_id]
  }
  environment {
    variables = {
      REDIS_URL: var.redis_url
      REGION: data.aws_region.current.name
      SECRET_ARN: var.secret_arn
    }
  }
}
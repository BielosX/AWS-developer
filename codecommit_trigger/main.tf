provider "aws" {}

resource "aws_codecommit_repository" "demo_repository" {
  repository_name = "demo_repository"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

data "archive_file" "lambda_code" {
  source_file = "${path.module}/main.py"
  output_path = "${path.module}/main.zip"
  type = "zip"
}

resource "aws_lambda_function" "trigger_handler" {
  function_name = "trigger_handler"
  runtime = "python3.9"
  handler = "main.handler"
  role = aws_iam_role.lambda_role.arn
  filename = data.archive_file.lambda_code.output_path
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
}

resource "aws_codecommit_trigger" "demo_trigger" {
  repository_name = aws_codecommit_repository.demo_repository.repository_name
  trigger {
    destination_arn = aws_lambda_function.trigger_handler.arn
    events = ["all"]
    name = "demo_trigger"
    branches = ["master"]
  }
}

resource "aws_lambda_permission" "codecommit_permission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_handler.function_name
  principal = "codecommit.amazonaws.com"
}
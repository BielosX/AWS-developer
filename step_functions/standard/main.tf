provider "aws" {
  region = "eu-west-1"
}

data "aws_iam_policy_document" "sfn-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["states.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "lambda-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "sfn-role" {
  assume_role_policy = data.aws_iam_policy_document.sfn-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
}

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

data "archive_file" "first-sfn-lambda" {
  output_path = "${path.module}/first_sfn_lambda.zip"
  source_dir = "${path.module}/first_lambda"
  type = "zip"
}

resource "aws_lambda_function" "first-sfn-lambda" {
  function_name = "first-sfn-demo-lambda"
  role = aws_iam_role.lambda-role.arn
  runtime = "python3.8"
  handler = "handler.handle"
  filename = data.archive_file.first-sfn-lambda.output_path
  source_code_hash = data.archive_file.first-sfn-lambda.output_base64sha256
}

resource "aws_sfn_activity" "worker-activity" {
  name = "worker-activity"
}

resource "aws_sfn_state_machine" "demo-state-machine" {
  name = "demo-state-machine"
  definition = templatefile("${path.module}/states.json.tmpl", {
    first_lambda_arn: aws_lambda_function.first-sfn-lambda.arn,
    activity_arn: aws_sfn_activity.worker-activity.id
  })
  role_arn = aws_iam_role.sfn-role.arn
  type = "STANDARD"
}

module "worker" {
  source = "./worker"
  worker-activity-arn = aws_sfn_activity.worker-activity.id
  worker-name = "ec2-worker"
}
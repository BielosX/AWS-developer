provider "aws" {
  region = "eu-west-1"
}

resource "aws_dynamodb_table" "first-demo-table" {
  name = "first-demo-table"
  hash_key = "userId"
  range_key = "created"
  billing_mode = "PROVISIONED"
  read_capacity = 10
  write_capacity = 10
  stream_enabled = true
  stream_view_type = "NEW_IMAGE"
  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "created"
    type = "S"
  }
}

resource "aws_dynamodb_table" "backup-demo-table" {
  name = "backup-demo-table"
  hash_key = "userId"
  range_key = "created"
  billing_mode = "PROVISIONED"
  read_capacity = 10
  write_capacity = 10
  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "created"
    type = "N"
  }
}

data "archive_file" "stream-handler" {
  output_path = "${path.module}/stream_handler.zip"
  source_file = "${path.module}/dynamodb_handler.py"
  type = "zip"
}

data "aws_iam_policy_document" "lambda-trust-policy" {
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

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-trust-policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
  ]
}

resource "aws_lambda_function" "stream-handler" {
  function_name = "dynamodb-stream-handler"
  runtime = "python3.8"
  handler = "dynamodb_handler.handle"
  timeout = 60
  filename = data.archive_file.stream-handler.output_path
  source_code_hash = data.archive_file.stream-handler.output_base64sha256
  role = aws_iam_role.lambda-role.arn
  environment {
    variables = {
      STATE_MACHINE_ARN: aws_sfn_state_machine.express-state-machine.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "lambda-dynamodb-mapping" {
  function_name = aws_lambda_function.stream-handler.arn
  starting_position = "LATEST"
  event_source_arn = aws_dynamodb_table.first-demo-table.stream_arn
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

resource "aws_iam_role" "sfn-role" {
  assume_role_policy = data.aws_iam_policy_document.sfn-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
}

data "archive_file" "splitter-lambda" {
  output_path = "${path.module}/splitter_lambda.zip"
  source_file = "${path.module}/splitter_lambda.py"
  type = "zip"
}

resource "aws_lambda_function" "splitter-lambda" {
  function_name = "splitter-lambda"
  runtime = "python3.8"
  handler = "splitter_lambda.handle"
  timeout = 60
  filename = data.archive_file.splitter-lambda.output_path
  source_code_hash = data.archive_file.splitter-lambda.output_base64sha256
  role = aws_iam_role.lambda-role.arn
}

data "archive_file" "copy-record-lambda" {
  output_path = "${path.module}/copy_record_lambda.zip"
  source_file = "${path.module}/copy_record_lambda.py"
  type = "zip"
}

resource "aws_lambda_function" "copy-record-lambda" {
  function_name = "copy-record-lambda"
  runtime = "python3.8"
  handler = "copy_record_lambda.handle"
  timeout = 60
  filename = data.archive_file.copy-record-lambda.output_path
  source_code_hash = data.archive_file.copy-record-lambda.output_base64sha256
  role = aws_iam_role.lambda-role.arn
  environment {
    variables = {
      BACKUP_TABLE: aws_dynamodb_table.backup-demo-table.name
    }
  }
}

resource "aws_sfn_state_machine" "express-state-machine" {
  definition = templatefile("${path.module}/states.json.tmpl", {
    splitter_lambda_arn: aws_lambda_function.splitter-lambda.arn,
    copy_record_lambda_arn: aws_lambda_function.copy-record-lambda.arn
  })
  name = "demo-express-state-machine"
  role_arn = aws_iam_role.sfn-role.arn
  type = "EXPRESS"
}
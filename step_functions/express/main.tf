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
  stream_view_type = "NEW_AND_OLD_IMAGES"
  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "created"
    type = "S"
  }
}

data "archive_file" "stream-handler" {
  output_path = "${path.module}/stream_handler.zip"
  source_file = "${path.module}/dynamodb_handler.py"
  type = "zip"
}

data "aws_iam_policy_document" "stream-lambda-trust-policy" {
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

resource "aws_iam_role" "stream-lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.stream-lambda-trust-policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  ]
}

resource "aws_lambda_function" "stream-handler" {
  function_name = "dynamodb-stream-handler"
  runtime = "python3.8"
  handler = "dynamodb_handler.handle"
  timeout = 60
  filename = data.archive_file.stream-handler.output_path
  source_code_hash = data.archive_file.stream-handler.output_base64sha256
  role = aws_iam_role.stream-lambda-role.arn
}

resource "aws_lambda_event_source_mapping" "lambda-dynamodb-mapping" {
  function_name = aws_lambda_function.stream-handler.arn
  starting_position = "LATEST"
  event_source_arn = aws_dynamodb_table.first-demo-table.stream_arn
}
provider "aws" {
  region = "eu-west-1"
}

resource "aws_dynamodb_table" "demo-table" {
  name     = "demo-table"
  hash_key = "user_id"
  billing_mode = "PROVISIONED"
  write_capacity = 1
  read_capacity = 1
  attribute {
    name = "user_id"
    type = "S"
  }
}

resource "aws_appautoscaling_target" "dynamodb-table-read-target" {
  max_capacity = 4
  min_capacity = 1
  resource_id = "table/${aws_dynamodb_table.demo-table.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "dynamodb-table-write-target" {
  max_capacity = 4
  min_capacity = 1
  resource_id = "table/${aws_dynamodb_table.demo-table.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb-table-read-policy" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb-table-read-target.resource_id}"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.dynamodb-table-read-target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb-table-read-target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb-table-read-target.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 50
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "dynamodb-table-write-policy" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb-table-write-target.resource_id}"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.dynamodb-table-write-target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb-table-write-target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb-table-write-target.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 50
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
  }
}

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
}

resource "aws_iam_role_policy_attachment" "attach-dynamodb-access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role = aws_iam_role.lambda-role.id
}

resource "aws_iam_role_policy_attachment" "attach-lambda-execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role = aws_iam_role.lambda-role.id
}

data "archive_file" "lambda-zip" {
  output_path = "${path.module}/handler.zip"
  source_file = "${path.module}/handler.py"
  type = "zip"
}

resource "aws_lambda_function" "dynamodb-demo-lambda" {
  function_name = "dynamodb-demo-lambda"
  role = aws_iam_role.lambda-role.arn
  reserved_concurrent_executions = 100
  runtime = "python3.8"
  handler = "handler.handle"
  filename = data.archive_file.lambda-zip.output_path
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  timeout = 60
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.demo-table.id
    }
  }
}
provider "aws" {
  region = "eu-west-1"
}

data "archive_file" "lambda-code" {
  type = "zip"
  output_path = "${path.module}/lambda.zip"
  source {
    content = <<-EOT

    import os

    def handle(event, context):
      if os.path.isfile('/tmp/test.txt'):
        f = open('/tmp/test.txt', 'r')
        content = f.read()
        print("file /tmp/test.txt exists, content: {}".format(content))
        f.close()
      else:
        print("file /tmp/test.txt does not exist. Creating...")
        f = open('/tmp/test.txt', 'a')
        f.write("Function version: {}, AWS Request ID: {}".format(context.function_version, context.aws_request_id))
        f.close()
      return "OK"

    EOT
    filename = "handler.py"
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

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

resource "aws_lambda_function" "demo-lambda" {
  function_name = "tmp-demo-lambda"
  runtime = "python3.8"
  role = aws_iam_role.lambda-role.arn
  handler = "handler.handle"
  filename = data.archive_file.lambda-code.output_path
  source_code_hash = data.archive_file.lambda-code.output_base64sha256
}
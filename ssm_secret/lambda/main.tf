
locals {
  zip_file = "${path.module}/test_lambda.zip"
}

resource "aws_lambda_function" "test_lambda" {
  function_name = "deployment_function"
  handler = "handler.handle"
  role = aws_iam_role.deployment_lambda_role.arn
  runtime = "python3.8"
  filename = local.zip_file
  source_code_hash = filebase64sha256(local.zip_file)
  timeout = 60
}

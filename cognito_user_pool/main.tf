provider "aws" {
  region = var.region
}

data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["apigateway.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "api_gateway_role" {
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role = aws_iam_role.api_gateway_role.id
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

data "aws_iam_policy_document" "lambda_invoke" {
  statement {
    effect = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_invoke" {
  policy = data.aws_iam_policy_document.lambda_invoke.json
  role = aws_iam_role.api_gateway_role.id
}

resource "aws_iam_role" "lambda_role" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_cognito_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonCognitoReadOnly"
  role = aws_iam_role.lambda_role.id
}

resource "aws_iam_role_policy_attachment" "attach_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role = aws_iam_role.lambda_role.id
}

data "archive_file" "lambda_archive" {
  output_path = "${path.module}/lambda.zip"
  source_file = "${path.module}/handle.py"
  type = "zip"
}

resource "aws_lambda_function" "user_details_lambda" {
  function_name = "user-details-lambda"
  handler = "handle.handle"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  timeout = 60
  filename = data.archive_file.lambda_archive.output_path
  source_code_hash = data.archive_file.lambda_archive.output_base64sha256
}

resource "aws_s3_bucket" "web_bucket" {
  acl = "public-read"
  force_destroy = true
  website {
    index_document = "index.html"
  }
}

resource "aws_cognito_user_pool" "demo-user-pool" {
  name = "demo-user-pool"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  mfa_configuration = "OFF"
  schema {
    attribute_data_type = "String"
    name = "email"
    mutable = true
    required = true
  }
  lifecycle {
    ignore_changes = [schema]
  }
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_domain" "demo-domain" {
  domain = "demo-domain"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
}


resource "aws_s3_bucket_object" "web_page_html" {
  for_each = fileset("${path.module}/src", "*.html")
  content = file("${path.module}/src/${each.value}")
  bucket = aws_s3_bucket.web_bucket.id
  content_type = "text/html"
  key = each.value
  acl = "public-read"
}

resource "aws_api_gateway_rest_api" "api" {
  name = "demo-api"
  body = templatefile("${path.module}/openapi.json.tmpl", {
    api_gw_role = aws_iam_role.api_gateway_role.arn
    bucket_name = aws_s3_bucket.web_bucket.id
    region = var.region
    lambda_invoke_arn = aws_lambda_function.user_details_lambda.invoke_arn
    user_pool_arn = aws_cognito_user_pool.demo-user-pool.arn
  })
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.api.body)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api-gateway-access-log-group" {
  name = "api-gw-access-logs"
}

resource "aws_iam_role" "api-gateway-logs-role" {
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_api_gw_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role = aws_iam_role.api-gateway-logs-role.id
}

resource "aws_api_gateway_account" "acc" {
  cloudwatch_role_arn = aws_iam_role.api-gateway-logs-role.arn
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = "prod"
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api-gateway-access-log-group.arn
    format = "$context.identity.sourceIp,$context.identity.caller,$context.identity.user,$context.requestTime,$context.httpMethod,$context.resourcePath,$context.protocol,$context.status,$context.responseLength,$context.requestId,$context.integrationErrorMessage,$context.error.message"
  }
}

resource "aws_cognito_user_pool_client" "web-client" {
  name = "web-client"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows = ["implicit", "code"]
  callback_urls = ["${aws_api_gateway_stage.prod.invoke_url}/token.html"]
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  generate_secret = false
  allowed_oauth_scopes = ["profile", "email", "openid"]
  supported_identity_providers = ["COGNITO"]
  prevent_user_existence_errors = "ENABLED"
}

resource "aws_s3_bucket_object" "metadata" {
  bucket = aws_s3_bucket.web_bucket.id
  key = "metadata.json"
  content_type = "application/json"
  acl = "public-read"
  content = jsonencode(
  {
    "clientId" = aws_cognito_user_pool_client.web-client.id
    "cognitoDomain"="${aws_cognito_user_pool_domain.demo-domain.domain}.auth.${var.region}.amazoncognito.com"
    "redirectUri"="${aws_api_gateway_stage.prod.invoke_url}/token.html"
  })
}
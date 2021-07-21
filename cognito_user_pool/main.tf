provider "aws" {
  region = "eu-west-1"
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

resource "aws_iam_role" "s3_access_role" {
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role = aws_iam_role.s3_access_role.id
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
    s3_access_role = aws_iam_role.s3_access_role.arn
    bucket_name = aws_s3_bucket.web_bucket.id
    region = "eu-west-1"
    cognito_domain_name = aws_cognito_user_pool_domain.demo-domain.domain
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

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = "prod"
}

resource "aws_cognito_user_pool_client" "web-client" {
  name = "web-client"
  user_pool_id = aws_cognito_user_pool.demo-user-pool.id
  allowed_oauth_flows = ["implicit"]
  callback_urls = ["${aws_api_gateway_stage.prod.invoke_url}/token.js"]
}

resource "aws_s3_bucket_object" "client_id" {
  bucket = aws_s3_bucket.web_bucket.id
  key = "client_id.json"
  content_type = "application/javascript"
  acl = "public-read"
  content = aws_cognito_user_pool_client.web-client.id
}
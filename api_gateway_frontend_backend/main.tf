provider "aws" {}

resource "aws_s3_bucket" "web-bucket" {
  bucket_prefix = "web-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "web-bucket-acl" {
  bucket = aws_s3_bucket.web-bucket.id
  acl = "public-read"
}

resource "aws_s3_object" "index-html" {
  bucket = aws_s3_bucket.web-bucket.id
  key = "index.html"
  source = "${path.module}/web/index.html"
  acl = "public-read"
  content_type = "text/html"
  source_hash = filemd5("${path.module}/web/index.html")
}

resource "aws_s3_bucket_website_configuration" "website-config" {
  bucket = aws_s3_bucket.web-bucket.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_apigatewayv2_api" "demo-api" {
  name = "demo-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "s3-integration" {
  api_id = aws_apigatewayv2_api.demo-api.id
  integration_type = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri = "http://${aws_s3_bucket_website_configuration.website-config.website_endpoint}"
}

resource "aws_apigatewayv2_route" "s3-route" {
  api_id = aws_apigatewayv2_api.demo-api.id
  route_key = "$default"
  target = "integrations/${aws_apigatewayv2_integration.s3-integration.id}"
}

resource "aws_apigatewayv2_stage" "api-stage" {
  api_id = aws_apigatewayv2_api.demo-api.id
  name = "app"
  auto_deploy = true
}

module "alb-lambda" {
  source = "../alb_lambda"
  internet-facing = false
  path-prefix = "/api"
}

resource "aws_security_group" "vpc-link-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
}

resource "aws_apigatewayv2_vpc_link" "vpc-link" {
  name = "vpc-link"
  security_group_ids = [aws_security_group.vpc-link-sg.id]
  subnet_ids = module.alb-lambda.alb-subnets
}

resource "aws_apigatewayv2_integration" "alb-integration" {
  api_id = aws_apigatewayv2_api.demo-api.id
  integration_type = "HTTP_PROXY"
  connection_type = "VPC_LINK"
  connection_id = aws_apigatewayv2_vpc_link.vpc-link.id
  integration_method = "ANY"
  integration_uri = module.alb-lambda.alb-listener-arn
  request_parameters = {
    "overwrite:path": "$request.path"
  }
}

resource "aws_apigatewayv2_route" "alb-route" {
  api_id = aws_apigatewayv2_api.demo-api.id
  route_key = "ANY /api/{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.alb-integration.id}"
}

provider "aws" {}

data "aws_vpc" "default-vpc" {
  default = true
}

data "aws_subnets" "default-subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default-vpc.id]
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
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSLambda_FullAccess",
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  ]
}

data "archive_file" "lambdas-listing-zip" {
  output_path = "${path.module}/lambdas.zip"
  type = "zip"
  source_file = "${path.module}/lambdas/main.py"
}

resource "aws_lambda_function" "lambdas-listing-lambda" {
  function_name = "lambdas-listing-lambda"
  role = aws_iam_role.lambda-role.arn
  runtime = "python3.9"
  filename = data.archive_file.lambdas-listing-zip.output_path
  source_code_hash = data.archive_file.lambdas-listing-zip.output_base64sha256
  handler = "main.handle"
}

data "archive_file" "queues-listing-zip" {
  output_path = "${path.module}/queues.zip"
  type = "zip"
  source_file = "${path.module}/queues/main.py"
}

resource "aws_lambda_function" "queues-listing-lambda" {
  function_name = "queues-listing-lambda"
  role = aws_iam_role.lambda-role.arn
  runtime = "python3.9"
  filename = data.archive_file.queues-listing-zip.output_path
  source_code_hash = data.archive_file.queues-listing-zip.output_base64sha256
  handler = "main.handle"
}

resource "aws_security_group" "alb-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
}

resource "aws_lb" "demo-alb" {
  name = "demo-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb-sg.id]
  subnets = data.aws_subnets.default-subnets.ids
}

resource "aws_lambda_permission" "allow_invoke_lambdas_list" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdas-listing-lambda.function_name
  principal = "elasticloadbalancing.amazonaws.com"
}

resource "aws_lambda_permission" "allow_invoke_queues_list" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.queues-listing-lambda.function_name
  principal = "elasticloadbalancing.amazonaws.com"
}

resource "aws_lb_target_group" "lambdas-listing-tg" {
  name = "lambdas-listing-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "lambdas-listing-attach" {
  depends_on = [aws_lambda_permission.allow_invoke_lambdas_list]
  target_group_arn = aws_lb_target_group.lambdas-listing-tg.arn
  target_id = aws_lambda_function.lambdas-listing-lambda.arn
}

resource "aws_lb_target_group" "queues-listing-tg" {
  name = "queues-listing-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "queues-listing-attach" {
  depends_on = [aws_lambda_permission.allow_invoke_queues_list]
  target_group_arn = aws_lb_target_group.queues-listing-tg.arn
  target_id = aws_lambda_function.queues-listing-lambda.arn
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.demo-alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/html"
      status_code = "404"
      message_body = "<html><body><h1>Not Found</h1></body></html>"
    }
  }
}

resource "aws_lb_listener_rule" "lambdas-listing-forward" {
  listener_arn = aws_lb_listener.http_listener.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.lambdas-listing-tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/lambdas*"]
    }
  }
}

resource "aws_lb_listener_rule" "queues-listing-forward" {
  listener_arn = aws_lb_listener.http_listener.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.queues-listing-tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/queues*"]
    }
  }
}

resource "aws_sqs_queue" "demo-queue" {
  name = "demo-queue"
}

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

locals {
  s3-origin-id = "WebsiteBucket"
  alb-origin-id = "Backend"
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3-origin-id
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  origin {
    origin_id = local.alb-origin-id
    domain_name = aws_lb.demo-alb.dns_name
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["SSLv3"]
    }
  }
  origin {
    origin_id = local.s3-origin-id
    domain_name = aws_s3_bucket.web-bucket.bucket_domain_name
  }
  ordered_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    path_pattern = "/api/*"
    target_origin_id = local.alb-origin-id
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
provider "aws" {}

locals {
  alb-path-prefix = "/api"
}

module "alb-lambda" {
  source = "../alb_lambda"
  path-prefix = local.alb-path-prefix
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
    domain_name = module.alb-lambda.alb-dns
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["SSLv3"]
    }
  }
  origin {
    origin_id = local.s3-origin-id
    domain_name = aws_s3_bucket.web-bucket.bucket_regional_domain_name
  }
  ordered_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    path_pattern = "${local.alb-path-prefix}/*"
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
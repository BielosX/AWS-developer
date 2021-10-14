provider "aws" {
  region = "eu-west-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "first-demo-bucket" {
  bucket = "first-cors-demo-bucket-${local.account_id}-${local.region}"
  acl = "public-read"
  force_destroy = true

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["http://${aws_s3_bucket.second-demo-bucket.website_endpoint}"]
    allowed_headers = ["*"]
    max_age_seconds = 30
  }
}

resource "aws_s3_bucket_object" "first-bucket-object" {
  bucket = aws_s3_bucket.first-demo-bucket.id
  key = "hello.json"
  content_type = "application/json"
  acl = "public-read"
  content = <<-EOT
  {
    "message": "Hello from ${aws_s3_bucket.first-demo-bucket.bucket}"
  }
  EOT
}

resource "aws_s3_bucket" "second-demo-bucket" {
  bucket = "second-cors-demo-bucket-${local.account_id}-${local.region}"
  acl = "public-read"
  force_destroy = true
  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_object" "index-object" {
  bucket = aws_s3_bucket.second-demo-bucket.id
  key = "index.html"
  content_type = "text/html"
  acl = "public-read"
  content = <<-EOT
  <html>
    <script>
    function onClick() {
      var req = new XMLHttpRequest();
      req.open('GET', 'http://${aws_s3_bucket.first-demo-bucket.bucket_regional_domain_name}/hello.json', false); //works only with regional_domain_name, fails with domain_name
      req.setRequestHeader('Content-Type', 'application/json');
      req.setRequestHeader('Accept', 'application/json');
      req.send(null);
      if (req.status != 200) {
        alert("Request failed with code: " + req.status);
      }
      else {
        var message = JSON.parse(req.responseText).message;
        alert("Message: " + message);
      }
    }
    </script>
    <body>
      <h1>Hello from ${aws_s3_bucket.second-demo-bucket.bucket}</h1>
      <button onclick="onClick()">Click</button>
    </body>
  </html>
  EOT
}
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-test-bucket"
  acl = "private"
  force_destroy = true
}

data "aws_iam_policy_document" "sqs_allow_s3_bucket_send" {
  statement {
    effect = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      identifiers = ["*"]
      type = "*"
    }
    resources = [aws_sqs_queue.test_queue.arn]
    condition {
      test = "ArnEquals"
      values = [aws_s3_bucket.test_bucket.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue" "test_queue" {
  name = "test_queue"
}

resource "aws_sqs_queue_policy" "test_queue_policy" {
  policy = data.aws_iam_policy_document.sqs_allow_s3_bucket_send.json
  queue_url = aws_sqs_queue.test_queue.id
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  depends_on = [aws_sqs_queue_policy.test_queue_policy]
  bucket = aws_s3_bucket.test_bucket.id
  queue {
    events = ["s3:ObjectCreated:*"]
    queue_arn = aws_sqs_queue.test_queue.arn
  }
}
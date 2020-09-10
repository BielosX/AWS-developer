provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  bucket_prefix = "${local.account_id}-${var.region}"
}

resource "aws_s3_bucket" "test_bucket_logs" {
  force_destroy = true
  acl = "log-delivery-write"
  bucket = "${local.bucket_prefix}-test-bucket-logs"
}

resource "aws_s3_bucket" "test_bucket" {
  force_destroy = true
  acl = "private"
  bucket = "${local.bucket_prefix}-test-bucket"
  logging {
    target_bucket = aws_s3_bucket.test_bucket_logs.id
  }
}

resource "aws_s3_bucket" "athena_results" {
  force_destroy = true
  acl = "private"
  bucket = "${local.bucket_prefix}-athena-results"
}

resource "aws_athena_database" "logs_db" {
  bucket = aws_s3_bucket.athena_results.id
  name = "test_bucket_logs"
}

resource "aws_athena_workgroup" "workgroup" {
  name = "workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}"
    }
  }
}

resource "aws_athena_named_query" "create_table" {
  database = aws_athena_database.logs_db.name
  name = "create_table"
  workgroup = aws_athena_workgroup.workgroup.id
  query = <<EOT
    CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.logs_db.name}.test_bucket_logs(
         BucketOwner STRING,
         Bucket STRING,
         RequestDateTime STRING,
         RemoteIP STRING,
         Requester STRING,
         RequestID STRING,
         Operation STRING,
         Key STRING,
         RequestURI_operation STRING,
         RequestURI_key STRING,
         RequestURI_httpProtoversion STRING,
         HTTPstatus STRING,
         ErrorCode STRING,
         BytesSent BIGINT,
         ObjectSize BIGINT,
         TotalTime STRING,
         TurnAroundTime STRING,
         Referrer STRING,
         UserAgent STRING,
         VersionId STRING,
         HostId STRING,
         SigV STRING,
         CipherSuite STRING,
         AuthType STRING,
         EndPoint STRING,
         TLSVersion STRING
    )
    ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
    WITH SERDEPROPERTIES (
             'serialization.format' = '1', 'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) \\\"([^ ]*) ([^ ]*) (- |[^ ]*)\\\" (-|[0-9]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (\"[^\"]*\") ([^ ]*)(?: ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*))?.*$' )
    LOCATION 's3://${aws_s3_bucket.test_bucket_logs.bucket}/'
  EOT
}

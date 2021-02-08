data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "pipeline_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["codepipeline.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "pipeline_service_role" {
  assume_role_policy = data.aws_iam_policy_document.pipeline_assume_role.json
}

resource "aws_iam_role_policy_attachment" "pipeline_s3_full_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role = aws_iam_role.pipeline_service_role.id
}

resource "aws_s3_bucket" "artifacts_bucket" {
  force_destroy = true
  bucket = "artifacts-bucket-${local.account_id}-${local.region}"
}

resource "aws_s3_bucket" "source_bucket" {
  force_destroy = true
  bucket = "source-bucket-${local.account_id}-${local.region}"
}

resource "aws_codepipeline" "pipeline" {
  name = "Pipeline"
  role_arn = aws_iam_role.pipeline_service_role.arn
  artifact_store {
    location = aws_s3_bucket.artifacts_bucket.bucket
    type = "S3"
  }
  stage {
    name = "Source"
    action {
      category = "Source"
      name = "Source"
      owner = "AWS"
      provider = "S3"
      version = "1"
      output_artifacts = ["source_output"]
      configuration = {
        S3Bucket = aws_s3_bucket.source_bucket.bucket
        S3ObjectKey = "my-app.zip"
      }
    }
  }

  stage {
    name = "Build"
    action {
      category = "Build"
      name = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = var.code_build_project
      }
    }
  }
}

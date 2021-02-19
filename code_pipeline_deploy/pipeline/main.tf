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

data "aws_iam_policy_document" "invoke_lambda" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "lambda:InvokeFunction",
      "lambda:ListFunctions"
    ]
  }
}

resource "aws_iam_role_policy" "invoke_lambda_policy" {
  policy = data.aws_iam_policy_document.invoke_lambda.json
  role = aws_iam_role.pipeline_service_role.id
}

resource "aws_iam_role_policy_attachment" "pipeline_s3_full_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role = aws_iam_role.pipeline_service_role.id
}

resource "aws_iam_role_policy_attachment" "pipeline_codebuild_developer_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
  role = aws_iam_role.pipeline_service_role.id
}

resource "aws_s3_bucket" "artifacts_bucket" {
  force_destroy = true
  bucket = "artifacts-bucket-${local.account_id}-${local.region}"
  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket" "source_bucket" {
  force_destroy = true
  bucket = "source-bucket-${local.account_id}-${local.region}"
  versioning {
    enabled = true
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "deployment_lambda_role" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "codepipeline_result" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutJobFailureResult"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_codepipeline_result" {
  policy = data.aws_iam_policy_document.codepipeline_result.json
  role = aws_iam_role.deployment_lambda_role.id
}

resource "aws_iam_role_policy_attachment" "lambda_logs_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role = aws_iam_role.deployment_lambda_role.id
}

resource "aws_iam_role_policy_attachment" "lambda_code_deploy_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
  role = aws_iam_role.deployment_lambda_role.id
}

data "archive_file" "archive_lambda_code" {
  output_path = "${path.module}/deployment_lambda.zip"
  source_file = "${path.module}/deployment_lambda.py"
  type = "zip"
}

resource "aws_lambda_function" "deployment_function" {
  function_name = "deployment_function"
  handler = "deployment_lambda.handle"
  role = aws_iam_role.deployment_lambda_role.arn
  runtime = "python3.8"
  filename = data.archive_file.archive_lambda_code.output_path
  source_code_hash = filebase64sha256(data.archive_file.archive_lambda_code.output_path)
  timeout = 60
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
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = var.code_build_project
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      category = "Invoke"
      name = "Deploy"
      owner = "AWS"
      provider = "Lambda"
      version = "1"
      input_artifacts = ["build_output"]
      configuration = {
        FunctionName = aws_lambda_function.deployment_function.function_name
        UserParameters = jsonencode({
          "first_asg": var.first_asg
          "second_asg": var.second_asg
          "deployment_group": var.deployment_group
          "application_name": var.code_deploy_application
        })
      }
    }
  }
}


data "aws_iam_policy_document" "build_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["codebuild.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "build_service_role" {
  assume_role_policy = data.aws_iam_policy_document.build_assume_role.json
}

data "aws_iam_policy_document" "ecr_full_access" {
  statement {
    effect = "Allow"
    actions = ["ecr:*"]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "ecr_full_access" {
  policy = data.aws_iam_policy_document.ecr_full_access.json
}

resource "aws_iam_role_policy_attachment" "attach_ecr_full" {
  policy_arn = aws_iam_policy.ecr_full_access.arn
  role = aws_iam_role.build_service_role.id
}

resource "aws_iam_role_policy_attachment" "attach_vpc_full" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  role = aws_iam_role.build_service_role.id
}

resource "aws_iam_role_policy_attachment" "attach_logs_full" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role = aws_iam_role.build_service_role.id
}

resource "aws_iam_role_policy_attachment" "attach_s3_full" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role = aws_iam_role.build_service_role.id
}

resource "aws_security_group" "build_security_group" {
  vpc_id = var.vpc_id
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    protocol = "tcp"
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    protocol = "tcp"
    to_port = 443
  }
}

resource "aws_ecr_repository" "build_image_repo" {
  name = "build-image-repo"
}

data "aws_iam_policy_document" "build_image_repo_policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type = "*"
    }
    actions = ["ecr:*"]
  }
}

resource "aws_ecr_repository_policy" "build_image_repo_policy" {
  policy = data.aws_iam_policy_document.build_image_repo_policy.json
  repository = aws_ecr_repository.build_image_repo.name
}

resource "aws_codebuild_project" "run_ansible" {
  name = "BuildAndTest"
  service_role = aws_iam_role.build_service_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "${aws_ecr_repository.build_image_repo.repository_url}:latest"
    type = "LINUX_CONTAINER"
  }
  source {
    type = "CODEPIPELINE"
  }
  vpc_config {
    security_group_ids = [aws_security_group.build_security_group.id]
    subnets = var.subnets
    vpc_id = var.vpc_id
  }
}
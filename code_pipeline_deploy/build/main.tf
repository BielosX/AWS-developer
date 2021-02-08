
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

resource "aws_codebuild_project" "run_ansible" {
  name = "RunAnsible"
  service_role = aws_iam_role.build_service_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type = "LINUX_CONTAINER"
  }
  source {
    type = "CODEPIPELINE"
  }
  //vpc_config {
  //  security_group_ids = [aws_security_group.build_security_group.id]
  //  subnets = var.subnets
  //  vpc_id = var.vpc_id
  //}
}
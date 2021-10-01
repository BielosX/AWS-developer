provider "aws" {
  region = "eu-west-1"
}

resource "aws_kinesis_stream" "demo-stream" {
  name        = "demo-stream"
  shard_count = 1
  retention_period = 24
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes"
  ]
  encryption_type = "NONE"
}

data "aws_ami" "amazon-linux-2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "demo-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = -1
    to_port   = -1
    protocol  = "icmp"
  }
}

data "aws_iam_policy_document" "ec2-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "ec2-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonKinesisFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  ]
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.ec2-role.name
}

resource "aws_instance" "demo-producer" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  availability_zone = "eu-west-1a"
  vpc_security_group_ids = [aws_security_group.demo-sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/init.sh.tmpl", {
    kinesis_stream: aws_kinesis_stream.demo-stream.name
  })
}

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

data "archive_file" "lambda-zip" {
  output_path = "${path.module}/consumer.zip"
  source_file = "${path.module}/consumer.py"
  type = "zip"
}

locals {
  function_names = toset([for i in range(2): "kinesis-consumer-${i}"])
}

resource "aws_lambda_function" "lambda-consumers" {
  for_each = local.function_names
  function_name = each.value
  role = aws_iam_role.lambda-role.arn
  runtime = "python3.8"
  timeout = 60
  handler = "consumer.handle"
  filename = data.archive_file.lambda-zip.output_path
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  memory_size = 512
}

resource "aws_lambda_event_source_mapping" "event-mappings" {
  depends_on = [aws_lambda_function.lambda-consumers]
  for_each = local.function_names
  event_source_arn = aws_kinesis_stream.demo-stream.arn
  function_name = each.value
  starting_position = "LATEST"
}
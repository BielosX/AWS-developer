provider "aws" {
  region = "eu-west-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_elastic_beanstalk_application" "demo-app" {
  name = "demo-application"
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

resource "aws_iam_role" "worker-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" //for sqsd
  ]
}

resource "aws_iam_instance_profile" "worker-instance-profile" {
  role = aws_iam_role.worker-role.name
}

resource "aws_security_group" "worker-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol  = "tcp"
  }
}

resource "aws_sqs_queue" "worker-queue" {
  name = "worker-queue"
  visibility_timeout_seconds = 60
}

resource "aws_s3_bucket" "deployment-bucket" {
  bucket = "worker-deployment-bucket-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  acl = "private"
  force_destroy = true
}

data "archive_file" "init-archive" {
  source_dir = "${path.module}/src"
  output_path = "${path.module}/init-archive.zip"
  type = "zip"
}

resource "aws_s3_bucket_object" "init-version" {
  bucket = aws_s3_bucket.deployment-bucket.id
  key = "init-archive.zip"
  source = data.archive_file.init-archive.output_path
  etag = filemd5(data.archive_file.init-archive.output_path)
}

resource "time_static" "current" {}

resource "aws_elastic_beanstalk_application_version" "init-version" {
  depends_on = [aws_s3_bucket_object.init-version]
  application = aws_elastic_beanstalk_application.demo-app.id
  bucket = aws_s3_bucket.deployment-bucket.id
  key = aws_s3_bucket_object.init-version.key
  name = "init-version-${time_static.current.unix}"
}

resource "aws_elastic_beanstalk_environment" "worker-env" {
  application = aws_elastic_beanstalk_application.demo-app.name
  name = "worker-env"
  tier = "Worker"
  solution_stack_name = "64bit Amazon Linux 2 v3.3.6 running Python 3.8"
  version_label = aws_elastic_beanstalk_application_version.init-version.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = aws_iam_instance_profile.worker-instance-profile.name
  }
  setting {
    namespace = "aws:ec2:instances"
    name = "InstanceTypes"
    value = "t3.micro, t2.micro"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "SecurityGroups"
    value = aws_security_group.worker-sg.name
  }
  setting {
    namespace = "aws:elasticbeanstalk:sqsd"
    name = "WorkerQueueURL"
    value = aws_sqs_queue.worker-queue.url
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MinSize"
    value = 2
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MaxSize"
    value = 4
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "RollingUpdateEnabled"
    value = "true"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "RollingUpdateType"
    value = "Time"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "Timeout"
    value = "PT30M"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "DeploymentPolicy"
    value = "RollingWithAdditionalBatch"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSizeType"
    value = "Fixed"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSize"
    value = 1
  }
  setting {
    namespace = "aws:elasticbeanstalk:sqsd"
    name = "HttpPath"
    value = "/handle"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name = "StreamLogs"
    value = true
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name = "DeleteOnTerminate"
    value = true
  }
}
provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_elastic_beanstalk_solution_stack" "python-stack" {
  name_regex = "^64bit Amazon Linux 2 (.*) running Python 3.8$"
  most_recent = true
}

resource "aws_elastic_beanstalk_application" "demo-app" {
  name = "demo-app"
}

resource "aws_s3_bucket" "demo-app-bucket" {
  bucket = "demo-app-bucket-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "demo-app-bucket-acl" {
  bucket = aws_s3_bucket.demo-app-bucket.id
  acl = "private"
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

resource "aws_iam_role" "demo-app-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
  ]
}


resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.demo-app-role.id
}

resource "aws_elastic_beanstalk_environment" "demo-app-env" {
  application = aws_elastic_beanstalk_application.demo-app.id
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.python-stack.name
  name = "demo-app-env"
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t3.micro"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = aws_iam_instance_profile.instance-profile.id
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name = "SystemType"
    value = "enhanced"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "DeploymentPolicy"
    value = "RollingWithAdditionalBatch"
  }
}
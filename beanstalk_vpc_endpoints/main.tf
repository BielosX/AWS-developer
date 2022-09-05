provider "aws" {}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_elastic_beanstalk_solution_stack" "python-stack" {
  name_regex = "^64bit Amazon Linux 2 (.*) running Python 3.8$"
  most_recent = true
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.demo-vpc.id
  map_public_ip_on_launch = true
  availability_zone_id = data.aws_availability_zones.available.zone_ids[0]
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, 1)
}

resource "aws_subnet" "private-subnet" {
  vpc_id = aws_vpc.demo-vpc.id
  availability_zone_id = data.aws_availability_zones.available.zone_ids[0]
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, 2)
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.demo-vpc.id
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
}

resource "aws_route_table_association" "public-route-table-assoc" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public-subnet.id
}

locals {
  region = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  interface-endpoints = [
    "com.amazonaws.${local.region}.cloudformation",
    "com.amazonaws.${local.region}.elasticbeanstalk-health",
    "com.amazonaws.${local.region}.elasticbeanstalk",
    "com.amazonaws.${local.region}.elasticbeanstalk",
    "com.amazonaws.${local.region}.sqs" // Required by https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-hup.html
  ]
}

resource "aws_security_group" "interface-endpoint-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = [aws_vpc.demo-vpc.cidr_block]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol  = "tcp"
  }
}

resource "aws_vpc_endpoint" "interface-endpoints" {
  count = length(local.interface-endpoints)
  service_name = local.interface-endpoints[count.index]
  vpc_id = aws_vpc.demo-vpc.id
  vpc_endpoint_type = "Interface"
  auto_accept = true
  private_dns_enabled = true
  security_group_ids = [aws_security_group.interface-endpoint-sg.id]
  subnet_ids = [aws_subnet.private-subnet.id]
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.demo-vpc.id
}

resource "aws_route_table_association" "private-route-table-assoc" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id = aws_subnet.private-subnet.id
}

data "aws_iam_policy_document" "s3-endpoint-policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["*"]
    resources = [
      "arn:aws:s3:::elasticbeanstalk-${local.region}-${local.account_id}",
      "arn:aws:s3:::elasticbeanstalk-${local.region}-${local.account_id}/*",
      "arn:aws:s3:::cloudformation-waitcondition-${local.region}/*"
    ]
  }
}

resource "aws_vpc_endpoint" "s3-endpoint" {
  service_name = "com.amazonaws.${local.region}.s3"
  auto_accept = true
  vpc_id = aws_vpc.demo-vpc.id
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private-route-table.id]
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

resource "aws_elastic_beanstalk_application" "demo-app" {
  name = "demo-app"
}

resource "aws_s3_bucket" "demo-artifacts" {
  bucket = "demo-app-artifacts-${local.region}-${local.account_id}"
}

resource "aws_s3_bucket_acl" "demo-artifacts-acl" {
  bucket = aws_s3_bucket.demo-artifacts.id
  acl = "private"
}

// Required, sample application runs pip install -r requirements.txt, it requires internet access
// For java stack it runs maven build that tries to download plugins and also fails
resource "aws_s3_object" "init-version" {
  bucket = aws_s3_bucket.demo-artifacts.id
  key = "init.zip"
  source = "${path.module}/latest.zip"
}

resource "aws_elastic_beanstalk_application_version" "init-version" {
  application = aws_elastic_beanstalk_application.demo-app.id
  bucket = aws_s3_bucket.demo-artifacts.id
  key = aws_s3_object.init-version.key
  name = "init-version"
}

resource "aws_elastic_beanstalk_environment" "demo-app-env" {
  depends_on = [aws_vpc_endpoint.interface-endpoints, aws_vpc_endpoint.s3-endpoint]
  application = aws_elastic_beanstalk_application.demo-app.name
  version_label = aws_elastic_beanstalk_application_version.init-version.name
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
    namespace = "aws:ec2:vpc"
    name = "Subnets"
    value = aws_subnet.private-subnet.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "ELBSubnets"
    value = aws_subnet.public-subnet.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "VPCId"
    value = aws_vpc.demo-vpc.id
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name = "StreamLogs"
    value = true
  }

  lifecycle {
    ignore_changes = [version_label]
  }
}
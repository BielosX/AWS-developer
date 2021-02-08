resource "aws_autoscaling_group" "app_deployment_asg" {
  max_size = 2
  min_size = 1
  launch_template {
    id = aws_launch_template.deployment_launch_template.id
    version = aws_launch_template.deployment_launch_template.latest_version
  }
  tag {
    key = "Name"
    value = "MyDeployment"
    propagate_at_launch = true
  }
  tag {
    key = "Deployment"
    value = "MyDeployment"
    propagate_at_launch = true
  }
  vpc_zone_identifier = var.subnets
}

data "aws_ami" "amazon_linux_2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "description"
    values = ["Amazon Linux 2 AMI*"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "deployment_security_group" {
  vpc_id = var.vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    protocol = "tcp"
    to_port = 80
  }
}

resource "aws_launch_template" "deployment_launch_template" {
  image_id = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.deployment_security_group.id]
}

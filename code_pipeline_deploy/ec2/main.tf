data "aws_region" "current" {}

resource "aws_autoscaling_group" "app_deployment_asg" {
  max_size = 2
  min_size = 1
  launch_template {
    id = aws_launch_template.deployment_launch_template.id
    version = aws_launch_template.deployment_launch_template.latest_version
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
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name = "cloudwatch_agent_config"
  type = "String"
  value = file("${path.module}/amazon-cloudwatch-agent.json")
}

data "aws_iam_policy_document" "deployment_role_assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "deployment_role" {
  assume_role_policy = data.aws_iam_policy_document.deployment_role_assume.json
}

resource "aws_iam_role_policy_attachment" "attach_cw_agent_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role = aws_iam_role.deployment_role.id
}

resource "aws_iam_role_policy_attachment" "attach_ssm_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  role = aws_iam_role.deployment_role.id
}

resource "aws_iam_instance_profile" "instance_profile" {
  role = aws_iam_role.deployment_role.name
}

resource "aws_launch_template" "deployment_launch_template" {
  image_id = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.deployment_security_group.id]
  user_data = base64encode(templatefile("${path.module}/setup_env.sh.tmpl", {
    region = data.aws_region.current.name
    config_param = aws_ssm_parameter.cloudwatch_agent_config.name
  }))
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance_profile.arn
  }
}

resource "aws_elb" "deployment_elb" {
  listener {
    instance_port = 5000
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  internal = false
  health_check {
    healthy_threshold = 2
    interval = 30
    target = "HTTP:5000/health"
    timeout = 3
    unhealthy_threshold = 2
  }
  subnets = var.lb_subnets
}

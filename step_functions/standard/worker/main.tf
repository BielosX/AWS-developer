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

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_iam_role" "worker-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_instance_profile" "worker-instance-profile" {
  role = aws_iam_role.worker-role.name
}

resource "aws_security_group" "worker-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
}

resource "aws_instance" "worker-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.worker-instance-profile.id
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [aws_security_group.worker-sg.id]
  associate_public_ip_address = true
  user_data = <<-EOT

  #!/bin/bash

  pip3 install boto3
  wget https://s3.eu-west-1.amazonaws.com/amazoncloudwatch-agent-eu-west-1/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm -U ./amazon-cloudwatch-agent.rpm

  cat<<EOF >> /etc/amazon-cloudwatch-agent.json
  {
    "logs": {
      "logs_collected": {
        "files": {
          "collect_list": [
            {
              "file_path": "/var/log/worker.log",
              "log_group_name": "/var/log/worker.log",
              "log_stream_name": "{instance_id}"
            }
          ]
        }
      }
    }
  }
  EOF

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/etc/amazon-cloudwatch-agent.json

  mkdir -p /opt/worker
  chmod +rw /opt/worker

  cat<<EOF >> /opt/worker/worker.py
  import logging
  import time
  import boto3
  import json
  from logging.handlers import RotatingFileHandler

  def main():
    logger = logging.getLogger("Rotating Log")
    logger.setLevel(logging.INFO)

    handler = RotatingFileHandler('/var/log/worker.log', maxBytes=4096, backupCount=2)
    logger.addHandler(handler)

    client = boto3.client('stepfunctions')

    while True:
      logger.info('Trying to get activity task...')
      response = client.get_activity_task(
        activityArn='${var.worker-activity-arn}',
        workerName='${var.worker-name}'
      )
      task_token = response['taskToken']
      if not task_token:
        logger.info('Nothing to do...')
      else:
        logger.info('Task fetched. Input: {}'.format(response['input']))
        output = json.dumps({'result': 'Hello from EC2 Worker'})
        client.send_task_success(
          taskToken=task_token,
          output=output
        )
      time.sleep(2.0)

  if __name__ == '__main__':
    main()
  EOF


  cat <<EOF >> /usr/lib/systemd/system/worker.service
  [Unit]
  After=network.target

  [Service]
  Type=simple
  Restart=always
  RestartSec=5
  ExecStart=/usr/bin/python3 -u /opt/worker/worker.py
  StandardOutput=journal
  StandardError=journal
  Environment="AWS_DEFAULT_REGION=eu-west-1"

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl enable worker.service
  systemctl start worker.service

  EOT
}
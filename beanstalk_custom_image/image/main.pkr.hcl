data "amazon-ami" "python3-platform" {
  owners = ["amazon"]
  most_recent = true
  region = "eu-west-1"
  filters = {
    virtualization-type = "hvm"
    name = "aws-elasticbeanstalk-amzn-2.0.*.64bit-eb_python38_amazon_linux_2-hvm-*"
    root-device-type = "ebs"
  }
}

source "amazon-ebs" "main" {
  ami_name = "python3-custom-{{timestamp}}"
  region = "eu-west-1"
  profile = "default"
  instance_type = "t3.micro"
  ssh_username = "ec2-user"
  source_ami = data.amazon-ami.python3-platform.id
  tag {
    key = "Name"
    value = "python3-custom-image"
  }
}

build {
  sources = ["source.amazon-ebs.main"]
  provisioner "shell" {
    script = "install.sh"
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }
}
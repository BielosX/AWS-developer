provider "aws" {
  region = "eu-west-1"
}

data "aws_vpc" "simple" {
  filter {
    name = "tag:Name"
    values = ["SimpleVPC"]
  }
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.simple.id
  filter {
    name = "tag:Name"
    values = ["Private"]
  }
}

data "aws_subnet_ids" "public_subnets" {
  vpc_id = data.aws_vpc.simple.id
  filter {
    name = "tag:Name"
    values = ["Public"]
  }
}

module "ec2" {
  source = "./ec2"
  subnets = data.aws_subnet_ids.private_subnets.ids
  vpc_id = data.aws_vpc.simple.id
  lb_subnets = data.aws_subnet_ids.public_subnets.ids
}

module "build" {
  source = "./build"
  subnets = data.aws_subnet_ids.private_subnets.ids
  vpc_id = data.aws_vpc.simple.id
}

module "deploy" {
  source = "./deploy"
  elb_name = module.ec2.elb_name
  blue_asg = module.ec2.first_auto_scaling_group
}

module "pipeline" {
  source = "./pipeline"
  code_build_project = module.build.build_project
  first_asg = module.ec2.first_auto_scaling_group
  second_asg = module.ec2.second_auto_scaling_group
  code_deploy_application = module.deploy.application_name
  deployment_group = module.deploy.deployment_group
}
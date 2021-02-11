provider "aws" {
  region = "eu-west-1"
}

data "aws_vpc" "simple" {
  filter {
    name = "tag:Name"
    values = ["SimpleVPC"]
  }
}

data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.simple.id
  filter {
    name = "tag:Name"
    values = ["Private"]
  }
}

module "ec2" {
  source = "./ec2"
  subnets = data.aws_subnet_ids.subnets.ids
  vpc_id = data.aws_vpc.simple.id
}

module "build" {
  source = "./build"
  subnets = data.aws_subnet_ids.subnets.ids
  vpc_id = data.aws_vpc.simple.id
}

module "pipeline" {
  source = "./pipeline"
  code_build_project = module.build.build_project
}
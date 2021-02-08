provider "aws" {
  region = "eu-west-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.default.id
}

module "ec2" {
  source = "./ec2"
  subnets = data.aws_subnet_ids.subnets.ids
  vpc_id = data.aws_vpc.default.id
}

module "build" {
  source = "./build"
  subnets = data.aws_subnet_ids.subnets.ids
  vpc_id = data.aws_vpc.default.id
}

module "pipeline" {
  source = "./pipeline"
  code_build_project = module.build.build_project
}
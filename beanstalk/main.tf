provider "aws" {
  region = "eu-west-1"
}

module "worker" {
  source = "./worker"
}
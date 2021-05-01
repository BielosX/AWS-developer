provider "aws" {
  region = "eu-west-1"
}

module "redis" {
  source = "./redis"
}
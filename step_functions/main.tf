provider "aws" {
  region = "eu-west-1"
}

module "express" {
  source = "./express"
}

module "standard" {
  source = "./standard"
}
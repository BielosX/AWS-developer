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

module "secret" {
  source = "./secret"
}

data "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = module.secret.secret_arn
}

module "redis" {
  source = "./redis"
  private_subnet_id = tolist(data.aws_subnet_ids.private_subnets.ids)[0]
  vpc_id = data.aws_vpc.simple.id
  auth_token = data.aws_secretsmanager_secret_version.redis_auth_token.secret_string
}

module "lambda" {
  source = "./lambda"
  redis_url = module.redis.redis_url
  private_subnet_id = tolist(data.aws_subnet_ids.private_subnets.ids)[0]
  vpc_id = data.aws_vpc.simple.id
  secret_arn = data.aws_secretsmanager_secret_version.redis_auth_token.arn
}
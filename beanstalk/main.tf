provider "aws" {
  region = "eu-west-1"
}

module "worker" {
  source = "./worker"
}

module "webapp" {
  source = "./webapp"
  worker_queue_url = module.worker.worker_queue_url
}
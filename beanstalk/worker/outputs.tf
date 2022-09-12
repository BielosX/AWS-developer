output "worker_queue_url" {
  value = aws_elastic_beanstalk_environment.worker-env.queues[0]
}
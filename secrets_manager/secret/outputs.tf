output "secret_arn" {
  value = lookup(aws_cloudformation_stack.redis_secret.outputs, "SecretArn", "")
}
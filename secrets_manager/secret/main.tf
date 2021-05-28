resource "aws_cloudformation_stack" "redis_secret" {
  name = "redis-secret"
  template_body = file("${path.module}/secret.yaml")
}
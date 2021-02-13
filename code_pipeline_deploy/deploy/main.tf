resource "aws_codedeploy_app" "my_app" {
  name = "my_app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_config" "my_app_config" {
  deployment_config_name = "my_app_config"

  minimum_healthy_hosts {
    type = "HOST_COUNT"
    value = 1
  }
}
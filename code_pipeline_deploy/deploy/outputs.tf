output "application_name" {
  value = aws_codedeploy_app.my_app.name
}

output "deployment_group" {
  value = aws_codedeploy_deployment_group.my_app_deployment_group.deployment_group_name
}
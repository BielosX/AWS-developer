output "first_auto_scaling_group" {
  value = aws_autoscaling_group.first_app_deployment_asg.id
}

output "second_auto_scaling_group" {
  value = aws_autoscaling_group.second_app_deployment_asg.id
}

output "elb_name" {
  value = aws_elb.deployment_elb.name
}
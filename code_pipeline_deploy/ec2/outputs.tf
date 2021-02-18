output "auto_scaling_group" {
  value = aws_autoscaling_group.app_deployment_asg.id
}

output "elb_name" {
  value = aws_elb.deployment_elb.name
}
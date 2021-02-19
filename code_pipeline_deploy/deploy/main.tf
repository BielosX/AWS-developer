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

data "aws_iam_policy_document" "codedeploy_service-role_assume" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["codedeploy.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codedeploy_service_role" {
  assume_role_policy = data.aws_iam_policy_document.codedeploy_service-role_assume.json
}

resource "aws_iam_role_policy_attachment" "assume_code_deploy_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_service_role.name
}

resource "aws_codedeploy_deployment_group" "my_app_deployment_group" {
  app_name = aws_codedeploy_app.my_app.name
  deployment_group_name = "MyDeploymentBlueGreen"
  service_role_arn = aws_iam_role.codedeploy_service_role.arn
  autoscaling_groups = [var.blue_asg]
  load_balancer_info {
    elb_info {
      name = var.elb_name
    }
  }
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type = "BLUE_GREEN"
  }
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action = "KEEP_ALIVE"
    }
    green_fleet_provisioning_option {
      action = "DISCOVER_EXISTING"
    }
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }
}
output "alb-dns" {
  value = aws_lb.demo-alb.dns_name
}

output "alb-subnets" {
  value = data.aws_subnets.default-subnets.ids
}

output "alb-arn" {
  value = aws_lb.demo-alb.arn
}

output "alb-listener-arn" {
  value = aws_lb_listener.http_listener.arn
}
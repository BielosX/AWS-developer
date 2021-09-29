output "vpc_id" {
  value = aws_vpc.simple_vpc.id
}

output "private_subnet_id" {
  value = aws_subnet.private-subnet.id
}

output "s3-endpoint-id" {
  value = aws_vpc_endpoint.s3-endpoint.id
}
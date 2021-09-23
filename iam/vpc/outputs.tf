output "vpc_id" {
  value = aws_vpc.simple_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}
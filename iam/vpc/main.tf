resource "aws_vpc" "simple_vpc" {
  cidr_block = "10.0.0.0/22"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "SimpleVPC"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private-subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.simple_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "Private"
  }
}

resource "aws_subnet" "public-subnet" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.simple_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "Public"
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.simple_vpc.id
}

resource "aws_route_table_association" "private-route-table-assoc" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id = aws_subnet.private-subnet.id
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.simple_vpc.id
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.simple_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
}

resource "aws_route_table_association" "public-route-table-assoc" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public-subnet.id
}

resource "aws_security_group" "endpoint-sg" {
  vpc_id = aws_vpc.simple_vpc.id
  ingress {
    cidr_blocks = [aws_subnet.private-subnet.cidr_block]
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
  egress {
    cidr_blocks = [aws_subnet.private-subnet.cidr_block]
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
}

locals {
  interface_endpoints = [
    "com.amazonaws.eu-west-1.ssm",
    "com.amazonaws.eu-west-1.ssmmessages",
    "com.amazonaws.eu-west-1.ec2messages"
  ]
}

resource "aws_vpc_endpoint" "interface-endpoints" {
  for_each = toset(local.interface_endpoints)
  service_name = each.value
  vpc_id       = aws_vpc.simple_vpc.id
  auto_accept = true
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private-subnet.id]
  security_group_ids = [aws_security_group.endpoint-sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3-endpoint" {
  service_name = "com.amazonaws.eu-west-1.s3"
  vpc_id       = aws_vpc.simple_vpc.id
  auto_accept = true
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private-route-table.id]
}
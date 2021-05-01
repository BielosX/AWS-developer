resource "aws_elasticache_subnet_group" "redis_subnets" {
  name = "redisSubnets"
  subnet_ids = [var.private_subnet_id]
}

locals {
  redis_port = 6379
}

resource "aws_security_group" "redis_sg" {
  vpc_id = var.vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = local.redis_port
    protocol = "tcp"
    to_port = local.redis_port
  }
}

resource "aws_elasticache_replication_group" "redis_cluster" {
  transit_encryption_enabled = true
  replication_group_description = "redis cluster"
  replication_group_id = "redis-cluster"
  node_type = "cache.t3.micro"
  parameter_group_name = "default.redis6.x"
  engine_version = "6.x"
  engine = "redis"
  number_cache_clusters = 1
  port = local.redis_port
  security_group_ids = [aws_security_group.redis_sg.id]
  subnet_group_name = aws_elasticache_subnet_group.redis_subnets.name
  auth_token = var.auth_token
}
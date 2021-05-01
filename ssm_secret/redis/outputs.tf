output "redis_url" {
  value = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
}
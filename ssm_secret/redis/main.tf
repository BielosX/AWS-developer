data "aws_availability_zones" "available" {
  state = "available"
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
  port = 6379
  availability_zones = [data.aws_availability_zones.available.names[0]]
}
# modules/elasticache/outputs.tf
# -------------------------------------------------------------------
# Outputs for consumption by other modules and the environment root.
#
# Key consumers:
#   - ECS task definition: needs primary_endpoint for environment
#     variables (the app connects here for caching)
#   - Phase 5 monitoring: needs replication_group_id for CloudWatch
#     alarms (cache hit rate, evictions, CPU)
# -------------------------------------------------------------------

output "primary_endpoint_address" {
  description = "Primary endpoint address (for read/write operations)"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Reader endpoint address (for read-only operations, useful with replicas)"
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Valkey port"
  value       = aws_elasticache_replication_group.this.port
}

output "replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.this.id
}

output "replication_group_arn" {
  description = "ElastiCache replication group ARN"
  value       = aws_elasticache_replication_group.this.arn
}

output "subnet_group_name" {
  description = "ElastiCache subnet group name"
  value       = aws_elasticache_subnet_group.this.name
}

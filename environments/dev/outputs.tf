output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  value = module.vpc.app_subnet_ids
}

output "data_subnet_ids" {
  value = module.vpc.data_subnet_ids
}

output "nat_gateway_ips" {
  value = module.vpc.nat_gateway_ips
}
output "kms_key_arn" {
  description = "ARN of the main KMS encryption key"
  value       = module.kms.key_arn
}

output "kms_key_alias" {
  description = "Alias of the main KMS encryption key"
  value       = module.kms.key_alias
}
output "db_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = module.secrets.db_credentials_secret_arn
}
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC role"
  value       = module.iam.github_actions_role_arn
}
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = module.security_groups.alb_security_group_id
}

output "app_security_group_id" {
  description = "Security group ID for app tier"
  value       = module.security_groups.app_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = module.security_groups.rds_security_group_id
}

output "redis_security_group_id" {
  description = "Security group ID for Redis"
  value       = module.security_groups.redis_security_group_id
}
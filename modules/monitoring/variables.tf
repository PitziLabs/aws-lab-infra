# modules/monitoring/variables.tf

variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# --- Notification ---

variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string
}

# --- ECS dimensions ---

variable "ecs_cluster_name" {
  description = "ECS cluster name (CloudWatch dimension)"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name (CloudWatch dimension)"
  type        = string
}

# --- ALB dimensions ---

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch dimensions"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch dimensions"
  type        = string
}

# --- RDS dimensions ---

variable "rds_instance_id" {
  description = "RDS instance identifier for CloudWatch dimensions"
  type        = string
}

# --- ElastiCache dimensions ---

variable "elasticache_replication_group_id" {
  description = "ElastiCache replication group ID for CloudWatch dimensions"
  type        = string
}

# --- Alarm thresholds (with sensible defaults) ---

variable "ecs_cpu_threshold" {
  description = "ECS CPU utilization alarm threshold (percent)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "ECS memory utilization alarm threshold (percent)"
  type        = number
  default     = 80
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx error count threshold (per evaluation period)"
  type        = number
  default     = 10
}

variable "alb_target_response_time_threshold" {
  description = "ALB target response time threshold (seconds)"
  type        = number
  default     = 2
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization alarm threshold (percent)"
  type        = number
  default     = 80
}

variable "rds_free_storage_threshold" {
  description = "RDS free storage space alarm threshold (bytes). Default ~4 GiB"
  type        = number
  default     = 4294967296
}

variable "elasticache_cpu_threshold" {
  description = "ElastiCache EngineCPUUtilization alarm threshold (percent)"
  type        = number
  default     = 80
}

variable "elasticache_memory_threshold" {
  description = "ElastiCache DatabaseMemoryUsagePercentage alarm threshold"
  type        = number
  default     = 80
}

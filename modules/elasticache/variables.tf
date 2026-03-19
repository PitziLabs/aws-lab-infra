# modules/elasticache/variables.tf
# -------------------------------------------------------------------
# Input contract for the ElastiCache Valkey module.
#
# Using Valkey (AWS-backed Redis fork) over Redis OSS:
#   - 20% cheaper for node-based deployments
#   - API-compatible (same commands, same client libraries)
#   - Where AWS is actively investing
# -------------------------------------------------------------------

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# --- Network dependencies (from VPC module) ---

variable "data_subnet_ids" {
  description = "List of data-tier private subnet IDs for the cache subnet group"
  type        = list(string)
}

# --- Security dependencies (from Phase 2 modules) ---

variable "redis_security_group_id" {
  description = "Security group ID allowing inbound Redis/Valkey traffic from app tier"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS CMK ARN for encryption at rest"
  type        = string
}

# --- Cache configuration ---

variable "engine_version" {
  description = "Valkey engine version (major.minor required for 7+)"
  type        = string
  default     = "7.2"
}

variable "node_type" {
  description = "ElastiCache node instance class"
  type        = string
  default     = "cache.t4g.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache clusters (nodes). 1 = single node, 2+ enables failover."
  type        = number
  default     = 1
}

variable "port" {
  description = "Port for Valkey connections"
  type        = number
  default     = 6379
}

variable "parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
  default     = "valkey7"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:06:00-sun:07:00"
}

variable "snapshot_retention_limit" {
  description = "Days to retain automatic snapshots (0 = disabled)"
  type        = number
  default     = 1
}

variable "snapshot_window" {
  description = "Daily snapshot window (UTC). Must not overlap maintenance window."
  type        = string
  default     = "04:00-05:00"
}

variable "apply_immediately" {
  description = "Apply changes immediately vs next maintenance window"
  type        = bool
  default     = true
}

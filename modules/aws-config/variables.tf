# modules/aws-config/variables.tf

variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Config delivery channel"
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix for Config delivery"
  type        = string
  default     = "config"
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for Config notifications (optional)"
  type        = string
  default     = ""
}

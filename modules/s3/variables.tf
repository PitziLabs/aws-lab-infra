# modules/s3/variables.tf
# -------------------------------------------------------------------
# Input contract for the S3 general-purpose bucket module.
# -------------------------------------------------------------------

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS CMK ARN for server-side encryption"
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it contains objects (true for lab)"
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions are permanently deleted"
  type        = number
  default     = 30
}

variable "log_expiration_days" {
  description = "Days before objects in the logs/ prefix are deleted"
  type        = number
  default     = 90
}

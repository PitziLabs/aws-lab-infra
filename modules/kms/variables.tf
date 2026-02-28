# modules/kms/variables.tf

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name for tagging and naming"
  type        = string
}

# The AWS account ID is needed in the key policy to grant root account access.
# We pass it in rather than using a data source so the module stays pure —
# no hidden data source calls that make testing and reasoning harder.
variable "aws_account_id" {
  description = "AWS account ID for key policy"
  type        = string
}

# We'll start with an empty list and add role ARNs as we create them in the IAM module.
# This is the "grant encrypt/decrypt to these principals" list.
variable "service_role_arns" {
  description = "List of IAM role ARNs that should be granted encrypt/decrypt usage of this key"
  type        = list(string)
  default     = []
}

# CloudWatch Logs needs explicit permission in the key policy because it's a
# service principal (logs.<region>.amazonaws.com), not an IAM role. Same pattern
# applies to a few other AWS services that interact with KMS on your behalf.
variable "aws_region" {
  description = "AWS region (needed for CloudWatch Logs service principal in key policy)"
  type        = string
}

variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = string
}

variable "alert_thresholds" {
  description = "List of percentage thresholds to alert on"
  type        = list(number)
  default     = [50, 80, 100]
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for budget notifications"
  type        = string
}

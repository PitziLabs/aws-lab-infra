variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate with the WAF Web ACL"
  type        = string
}

variable "rate_limit" {
  description = "Maximum requests per 5-minute period per IP before rate limiting"
  type        = number
  default     = 2000
}

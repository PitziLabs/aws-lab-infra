# modules/dns/variables.tf

variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name for the hosted zone (e.g., icecreamtofightover.com)"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names for the TLS certificate (e.g., [\"*.icecreamtofightover.com\"] for wildcard)"
  type        = list(string)
  default     = []
}
variable "create_alb_alias" {
  description = "Whether to create the ALB alias record (set to true once ALB module exists)"
  type        = bool
  default     = false
}

variable "alb_dns_name" {
  description = "DNS name of the ALB for the alias record"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Zone ID of the ALB for the alias record"
  type        = string
  default     = ""
}

# modules/monitoring/outputs.tf
# -------------------------------------------------------------------
# Outputs for consumption by other modules and the environment root.
#
# Key consumers:
#   - Phase 5c (CloudTrail): may use SNS topic for delivery notifications
#   - Phase 5d (AWS Config): may use SNS topic for compliance notifications
#   - Reference notes: SNS topic ARN for documentation
# -------------------------------------------------------------------

output "sns_topic_arn" {
  description = "ARN of the alerting SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the alerting SNS topic"
  value       = aws_sns_topic.alerts.name
}

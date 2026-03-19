# modules/s3/outputs.tf
# -------------------------------------------------------------------
# Outputs for consumption by other modules and the environment root.
#
# Key consumers:
#   - Phase 5: CloudTrail needs bucket ARN + name for log delivery
#   - Phase 5: VPC Flow Logs could also target this bucket
#   - Application: static asset storage
# -------------------------------------------------------------------

output "bucket_id" {
  description = "S3 bucket name (same as bucket ID in S3)"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name (for CloudFront origins, etc.)"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3 bucket region-specific domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

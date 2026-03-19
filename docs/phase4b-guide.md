# Phase 4b: S3 Bucket — Implementation Guide

## New Files (copy to `modules/s3/`)

```
modules/s3/
├── main.tf          ← Bucket, versioning, encryption, public block, lifecycle
├── variables.tf     ← Module interface
└── outputs.tf       ← Bucket ID, ARN, domain names
```

---

## Existing Files to Modify

### 1. `environments/dev/main.tf` — Add S3 module call

After the `module "rds"` block:

```hcl
module "s3" {
  source = "../../modules/s3"

  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arn
}
```

### 2. `environments/dev/outputs.tf` — Add S3 outputs

```hcl
output "s3_bucket_id" {
  description = "S3 general-purpose bucket name"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "S3 general-purpose bucket ARN"
  value       = module.s3.bucket_arn
}
```

---

## Apply

```bash
cd environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This one should take under 30 seconds — S3 buckets are metadata-only.

## Expected Resources: 5 new, 0 changed

1. aws_s3_bucket.this
2. aws_s3_bucket_versioning.this
3. aws_s3_bucket_server_side_encryption_configuration.this
4. aws_s3_bucket_public_access_block.this
5. aws_s3_bucket_lifecycle_configuration.this

## Expected Cost Impact

Effectively $0/month — S3 charges by storage used, not by bucket
existence. The KMS bucket key minimizes per-request KMS charges.
You'll only pay when you start putting objects in the bucket.

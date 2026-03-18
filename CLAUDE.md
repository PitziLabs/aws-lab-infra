# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS Lab Infrastructure — Terraform-based IaC project building a production-grade, three-tier AWS environment. Phases 0–3 (networking, encryption, IAM, secrets, compute/containers) are complete. Phases 4–7 (data, observability, CI/CD, security hardening) have placeholder modules.

## Common Commands

```bash
# One-time backend bootstrap (creates S3 bucket + DynamoDB table)
./scripts/bootstrap/bootstrap-backend.sh

# Initialize Terraform
cd environments/dev && terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Validate configuration without accessing remote state
terraform validate

# Format check
terraform fmt -check -recursive

# View outputs
terraform output
```

All Terraform commands run from `environments/dev/` (the only environment entry point currently).

## Quick Reference

| Item | Value |
|------|-------|
| Terraform version | >= 1.0 |
| AWS provider | ~> 5.0 (locked at 5.100.0) |
| AWS region | us-east-1 |
| AWS profile | aws-lab |
| Domain | hellavisible.net |
| GitHub org/repo | cpitzi/aws-lab-infra |

## Module Dependency Graph

```
VPC ──┐
      ├──→ Security Groups ──→ ALB ──┐
KMS ──┤                              ├──→ ECS ──→ ECS Autoscaling
      ├──→ Secrets ──→ IAM ──────────┘     ↑
      └──→ IAM (bidirectional with KMS)    │
                                           │
ECR ───────────────────────────────────────┘
DNS ←──→ ALB (certificate ↔ alias record)
```

**Bidirectional dependencies to watch:**
- **KMS ↔ IAM**: IAM needs KMS key ARN for decrypt permissions; KMS key policy needs IAM role ARNs to grant access.
- **DNS ↔ ALB**: DNS provides ACM certificate to ALB; ALB provides its DNS name/zone ID back for the Route 53 alias record.

## Architecture Conventions

**Naming**: `{project}-{environment}-{resource-type}` (e.g., `aws-lab-dev-ecs-cluster`).

**Tagging**: Applied via provider `default_tags` in `environments/dev/main.tf` (`Environment`, `Project`, `ManagedBy`). Individual resources add a `Name` tag.

**Module structure**: Every module has exactly `main.tf`, `variables.tf`, `outputs.tf`. Every module accepts `environment` and `project` variables.

**Security groups**: Rules reference security group IDs (not CIDRs) for Fargate compatibility. Groups are created as empty shells first, then rules are added as separate `aws_security_group_rule` resources to avoid circular references.

**`ignore_changes` patterns**:
- ECS service ignores `task_definition` and `desired_count` so CI/CD and auto-scaling can manage independently.
- Secrets Manager ignores `secret_string` to prevent Terraform from overwriting manual/automated rotations.

## Adding a New Module

1. Create `modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`
2. Include `environment` and `project` variables for consistent naming/tagging
3. Wire it into `environments/dev/main.tf` following the dependency graph order
4. Export relevant outputs in `environments/dev/outputs.tf`

## Key Files for Context

- `environments/dev/main.tf` — how all modules connect (the orchestration layer)
- `environments/dev/outputs.tf` — what each module exposes
- `modules/*/variables.tf` — what each module accepts

## Project Phases

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | Bootstrap backend, project structure | Complete |
| 1 | VPC, KMS, Secrets Manager | Complete |
| 2 | IAM roles, Security Groups | Complete |
| 3 | ECR, DNS/ACM, ALB, ECS Fargate, Auto-Scaling | Complete |
| 4 | RDS PostgreSQL, ElastiCache Redis | Planned |
| 5 | CloudWatch monitoring, alarms | Planned |
| 6 | GitHub Actions CI/CD workflows | Planned |
| 7 | WAF, Shield, GuardDuty | Planned |

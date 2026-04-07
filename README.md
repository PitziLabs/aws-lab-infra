# cloud-platform-demo

A production-grade, Terraform-managed AWS environment built as a portfolio project and learning lab. It hosts a live application at [icecreamtofightover.com](https://icecreamtofightover.com) and demonstrates the kind of infrastructure an ops veteran builds when they bring decades of production experience to modern cloud tooling.

## Why This Exists

Built by an infrastructure operations professional with 25+ years of production experience — bare-metal data centers, 24x7 ops, single-homed environments where every decision had physical consequences. This project bridges that experience into cloud-native architecture: not by reading about it, but by building it, breaking it, and operating it with real traffic.

Everything here reflects how a production environment should be built, scaled down to a single-account learning lab. No shortcuts on security posture. No placeholder modules. Real CI/CD, real monitoring, real cost controls.

## What's Deployed

A three-tier web application running on AWS, fully managed by Terraform:

**Networking:** VPC with public, application, and data subnets across two AZs. NAT Gateways for private subnet egress. VPC Flow Logs for network visibility.

**Compute:** ECS Fargate running an Astro/Nginx application behind an Application Load Balancer with HTTPS (ACM certificate, Route 53 DNS). Auto-scaling on CPU and memory thresholds.

**Data:** RDS PostgreSQL and ElastiCache (Valkey) in private subnets. Secrets Manager for credential management.

**Security:** WAFv2 Web ACL on the ALB with AWS Managed Rules (Common Rule Set, Known Bad Inputs, IP Reputation List) and a custom rate-limiting rule. KMS customer-managed key for encryption at rest. Security groups with least-privilege chaining — each tier can only reach the tier it needs.

**Observability:** CloudWatch dashboard covering ECS, ALB, WAF, RDS, ElastiCache, and NAT Gateway metrics. CloudWatch alarms with SNS email notifications. CloudTrail for API audit logging. AWS Config for compliance rules.

**Cost Management:** AWS Budgets with SNS alerts at 50%, 80%, and 100% of a $100/month threshold.

**CI/CD:** Two GitHub Actions pipelines with OIDC authentication (no stored credentials):
- **App deploy** — builds and deploys the container on content changes, with cross-repo dispatch from the content source repository
- **Terraform** — plans on PR (with plan output posted as a PR comment), applies on merge to main. Separate IAM role scoped to the `terraform` GitHub environment via OIDC sub-claim.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions                                             │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ App Deploy   │  │ Terraform    │                        │
│  │ (OIDC Role A)│  │ (OIDC Role B)│                        │
│  └──────┬───────┘  └──────┬───────┘                        │
└─────────┼─────────────────┼────────────────────────────────┘
          │                 │
          ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│  AWS Account (us-east-1)                                    │
│                                                             │
│  ┌─── WAF ──────────────────────────────────────────────┐   │
│  │                                                      │   │
│  │  ┌─── Public Subnets (2 AZs) ────────────────────┐  │   │
│  │  │  ALB (HTTPS) ──── Route 53 ──── ACM           │  │   │
│  │  │  Internet Gateway                              │  │   │
│  │  └────────────────────┬───────────────────────────┘  │   │
│  │                       │                              │   │
│  └───────────────────────┼──────────────────────────────┘   │
│                          │                                  │
│  ┌─── App Subnets (2 AZs) ──────────────────────────────┐  │
│  │  ECS Fargate (Astro/Nginx)                            │  │
│  │  NAT Gateways → Internet                              │  │
│  └────────────────────┬──────────────────────────────────┘  │
│                       │                                     │
│  ┌─── Data Subnets (2 AZs) ─────────────────────────────┐  │
│  │  RDS PostgreSQL    ElastiCache (Valkey)               │  │
│  │  Secrets Manager   KMS                                │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─── Observability ────────────────────────────────────┐   │
│  │  CloudWatch Dashboard + Alarms    CloudTrail          │  │
│  │  AWS Config Rules                 SNS Alerts          │  │
│  │  AWS Budgets                      VPC Flow Logs       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
cloud-platform-demo/
├── environments/
│   └── dev/
│       ├── main.tf              # Root module — wires all modules together
│       ├── variables.tf         # Environment-specific variables
│       ├── outputs.tf           # Exported values
│       └── terraform.tfvars     # Variable values for dev
├── modules/
│   ├── alb/                     # Application Load Balancer + listeners
│   ├── aws-config/              # AWS Config recorder + compliance rules
│   ├── budgets/                 # AWS Budgets with SNS alerts
│   ├── cloudtrail/              # CloudTrail audit logging
│   ├── dashboard/               # CloudWatch operational dashboard
│   ├── dns/                     # Route 53 + ACM certificate
│   ├── ecr/                     # Container registry + lifecycle policy
│   ├── ecs/                     # ECS cluster, service, task definition
│   ├── ecs-autoscaling/         # Application Auto Scaling policies
│   ├── elasticache/             # ElastiCache (Valkey) replication group
│   ├── iam/                     # IAM roles, policies, OIDC provider
│   ├── kms/                     # KMS customer-managed key
│   ├── monitoring/              # CloudWatch alarms + SNS topic
│   ├── rds/                     # RDS PostgreSQL instance
│   ├── s3/                      # S3 bucket with encryption + lifecycle
│   ├── secrets/                 # Secrets Manager
│   ├── security-groups/         # Security group rules (all SG logic here)
│   ├── vpc/                     # VPC, subnets, NAT Gateways, flow logs
│   └── waf/                     # WAFv2 Web ACL + ALB association
├── .github/
│   └── workflows/
│       ├── deploy.yml           # App deploy pipeline
│       ├── terraform.yml        # Terraform plan/apply pipeline
│       └── dispatch-deploy.yml  # Cross-repo dispatch receiver
└── docs/
    └── BOOTSTRAP.md             # Deployment runbook (start here)
```

## Design Decisions

### Separate IAM Roles for App Deploy and Terraform

The app deploy role can push containers and update ECS services. The Terraform role can manage infrastructure. Neither can do the other's job. The blast radius of a compromised pipeline is limited to its scope.

### OIDC Authentication, No Stored Secrets

Both pipelines authenticate via GitHub's OIDC provider. No AWS access keys in GitHub Secrets. The Terraform role's trust policy is scoped to the `terraform` GitHub environment, so only the `terraform.yml` workflow can assume it.

### Service-Level IAM Wildcards on the Terraform Role

The real security boundary is the OIDC sub-claim scoping, not per-action IAM restrictions. Service-level wildcards (`ec2:*`, `ecs:*`, etc.) keep the policy maintainable as modules evolve, while the OIDC trust ensures only the intended workflow can assume the role.

### One Module Per Domain

Security groups are centralized in one module to avoid Terraform resource conflicts. Each infrastructure domain (networking, compute, data, observability) has its own module with clear inputs and outputs.

### WAF with Managed Rules, Not Custom Rules

AWS Managed Rule Groups are free, auto-updated by AWS's threat research team, and cover the OWASP Top 10. Custom rules add complexity without meaningful benefit for a static content site. The rate-limiting rule is the only custom rule — simple and effective.

### CloudWatch Over Third-Party Observability

For a portfolio project demonstrating AWS skills, native CloudWatch is the right choice. The dashboard, alarms, and metrics all stay within the AWS ecosystem and demonstrate familiarity with the platform's observability tools.

### Platform, Not a Single-App Deployment

The infrastructure is deliberately decoupled from the application it hosts. The ECS cluster, ALB, data tier, and CI/CD pipelines are general-purpose — any containerized application can slot in by pushing an image to ECR and updating the task definition. A static Astro site, a Node.js API, a Python Flask service, or a scheduled batch job would all deploy through the same pipeline with different Dockerfiles. The cross-repo dispatch pattern already demonstrates this: content lives in a separate repository and triggers deployment independently. Adding a second application means adding a second task definition, target group, and listener rule — not rebuilding the platform. RDS and ElastiCache are available to any workload in the app subnets. The architecture is a foundation, not a one-off.

### Daily Destroy/Apply Pattern

This runs on personal money. The bootstrap runbook documents the tear-down and rebuild process. Terraform state persists in S3, so `terraform destroy` followed by `terraform apply` restores the full environment.

## Getting Started

See [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) for the complete deployment runbook. It covers everything from AWS account setup through pipeline verification.

## Cost

With all resources running 24/7, the environment costs approximately $130-140/month. The largest line items are NAT Gateways (~$65), ALB (~$16), RDS (~$15), and ElastiCache (~$12). Budget alerts notify via email at 50%, 80%, and 100% of a $100/month threshold.

## Related Repositories

- [**ice-cream-book**](https://github.com/PitziLabs/ice-cream-book) — Content source for the Astro/Nginx application. Pushes to main trigger cross-repo dispatch to deploy.
- [**PitziLabs**](https://github.com/PitziLabs) — GitHub organization housing this and related projects.

## License

This project is open source. See individual files for details.

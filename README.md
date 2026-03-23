# AWS Lab Infrastructure

Production-grade, three-tier AWS environment built entirely with Terraform. Designed as a learning lab that follows real-world patterns: multi-AZ networking, least-privilege IAM, encrypted secrets, containerized workloads on Fargate, and auto-scaling — all wired together through modular, reusable Terraform code.

## Architecture

```
                        Internet
                           │
                      ┌────┴────┐
                      │ Route 53│  icecreamtofightover.com
                      └────┬────┘
                           │
                    ┌──────┴──────┐
                    │  ACM (TLS)  │
                    └──────┬──────┘
                           │
               ┌───────────┴───────────┐
               │    ALB (public tier)   │  HTTPS :443, HTTP :80 → redirect
               │   us-east-1a / 1b     │
               └───────────┬───────────┘
                           │
               ┌───────────┴───────────┐
               │  ECS Fargate (app tier)│  2–6 tasks, auto-scaled
               │   us-east-1a / 1b     │  CPU + memory target tracking
               └───────────┬───────────┘
                           │
               ┌───────────┴───────────┐
               │   Data tier (planned)  │  RDS PostgreSQL, ElastiCache Redis
               │   us-east-1a / 1b     │
               └───────────────────────┘

    ECR ──→ container images
    KMS ──→ encryption at rest
    Secrets Manager ──→ DB credentials
    IAM ──→ least-privilege roles (ECS exec, ECS task, GitHub OIDC)
    CloudWatch ──→ container logs + Container Insights
```

### Network Layout

| Tier | Subnets | CIDR Blocks | Purpose |
|------|---------|-------------|---------|
| Public | 2 | 10.0.1.0/24, 10.0.2.0/24 | ALB, NAT Gateways |
| App | 2 | 10.0.10.0/24, 10.0.11.0/24 | ECS Fargate tasks (private) |
| Data | 2 | 10.0.20.0/24, 10.0.21.0/24 | RDS, ElastiCache (private) |

Each AZ has its own NAT Gateway to avoid cross-AZ bottlenecks and egress charges.

## Modules

| Module | Description | Status |
|--------|-------------|--------|
| `vpc` | Three-tier VPC with public/app/data subnets, NAT Gateways, flow logs | Complete |
| `kms` | Customer-managed encryption key with scoped key policy | Complete |
| `secrets` | Secrets Manager for database credentials (KMS-encrypted) | Complete |
| `iam` | ECS execution role, ECS task role, GitHub Actions OIDC role | Complete |
| `security-groups` | Identity-based SG rules (ALB → App → RDS/Redis) | Complete |
| `ecr` | Container registry with scan-on-push and lifecycle policies | Complete |
| `dns` | Route 53 hosted zone + ACM certificate with DNS validation | Complete |
| `alb` | Internet-facing ALB with HTTPS listener and HTTP redirect | Complete |
| `ecs` | Fargate cluster, task definition, service with rolling deploys | Complete |
| `ecs-autoscaling` | CPU + memory target-tracking scaling (2–6 tasks) | Complete |
| `rds` | PostgreSQL database | Planned |
| `elasticache` | Redis cache | Planned |
| `monitoring` | CloudWatch dashboards and alarms | Planned |
| `cicd` | GitHub Actions CI/CD workflows | Planned |
| `security` | WAF, Shield, GuardDuty | Planned |

### Module Dependency Graph

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

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configured with a named profile `aws-lab`
- An AWS account with permissions to create VPCs, IAM roles, ECS clusters, etc.
- A registered domain with nameservers pointed to the Route 53 hosted zone

## Getting Started

### 1. Bootstrap the Terraform Backend

Creates an S3 bucket (versioned, encrypted, private) and a DynamoDB table for state locking:

```bash
./scripts/bootstrap/bootstrap-backend.sh
```

### 2. Initialize and Apply

```bash
cd environments/dev

# Download providers and initialize backend
terraform init

# Preview changes
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

### 3. Configure DNS

After the first apply, retrieve the Route 53 nameservers and configure them at your domain registrar:

```bash
terraform output route53_name_servers
```

### 4. Push a Container Image

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 --profile aws-lab | \
  docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)

# Build, tag, and push
docker build -t my-app .
docker tag my-app:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest
```

## Key Design Decisions

### Security Groups Reference IDs, Not CIDRs
Fargate tasks get new IPs on every deployment. Security group rules reference other security group IDs so they remain valid regardless of IP changes.

### Separate Execution and Task Roles
The ECS **execution role** handles infrastructure concerns (pulling images, writing logs, reading secrets). The **task role** is for application-level AWS API access and starts minimal.

### ECS Service Ignores Task Definition and Desired Count
`ignore_changes` on `task_definition` and `desired_count` lets CI/CD pipelines deploy new image versions and auto-scaling adjust task count without Terraform reverting those changes.

### ACM Certificate Uses DNS Validation
Fully automated — Terraform creates the Route 53 validation records and waits for certificate issuance. No manual approval or email confirmation required.

### KMS Key Policy Structure
Four statements: root account escape hatch, key admin (no crypto operations), CloudWatch Logs service principal, and conditional grants for ECS roles. This prevents lockout while maintaining least privilege.

### Remote State with Locking
State is stored in S3 (versioned, encrypted) with DynamoDB locking to prevent concurrent applies. The bootstrap script sets this up before Terraform ever runs.

## Project Configuration

| Setting | Value |
|---------|-------|
| Region | `us-east-1` |
| AWS Profile | `aws-lab` |
| Project Name | `aws-lab` |
| Environment | `dev` |
| Domain | `icecreamtofightover.com` |
| State Bucket | `aws-lab-tfstate-365184644049` |
| Lock Table | `aws-lab-tfstate-lock` |
| Availability Zones | `us-east-1a`, `us-east-1b` |

## Outputs

After applying, key outputs are available via `terraform output`:

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC identifier |
| `public_subnet_ids` | Public subnet IDs (ALB placement) |
| `app_subnet_ids` | App subnet IDs (ECS task placement) |
| `data_subnet_ids` | Data subnet IDs (RDS/Redis placement) |
| `kms_key_arn` | KMS encryption key ARN |
| `ecr_repository_url` | ECR URL for docker push/pull |
| `alb_dns_name` | ALB DNS name |
| `acm_certificate_arn` | ACM certificate ARN |
| `route53_name_servers` | Nameservers for registrar config |
| `ecs_cluster_name` | ECS cluster name |
| `ecs_service_name` | ECS service name |

## Roadmap

- [ ] **Phase 4** — RDS PostgreSQL + ElastiCache Redis in data subnets
- [ ] **Phase 5** — CloudWatch dashboards, alarms, and SNS notifications
- [ ] **Phase 6** — GitHub Actions CI/CD (build, test, deploy via OIDC)
- [ ] **Phase 7** — WAF, Shield Advanced, GuardDuty

## Repository Conventions

- **Naming**: `{project}-{environment}-{resource}` (e.g., `aws-lab-dev-alb`)
- **Module structure**: Every module has exactly `main.tf`, `variables.tf`, `outputs.tf`
- **No committed secrets**: `.tfvars`, `.tfstate`, and credentials are gitignored
- **Tagging**: All resources inherit `Environment`, `Project`, `ManagedBy` via provider default tags

## Related

- **[PitziLabs/firewalla-axiom-pipeline](https://github.com/PitziLabs/firewalla-axiom-pipeline)** — Observability pipeline shipping Zeek IDS logs to Axiom — same homelab, different layer
- **[PitziLabs/setup-crostini-lab](https://github.com/PitziLabs/setup-crostini-lab)** — Chromebook bootstrap script with Terraform, AWS CLI, and kubectl pre-installed
- **[cpitzi/setup-xubuntu-lab](https://github.com/cpitzi/setup-xubuntu-lab)** — Xubuntu VM workstation bootstrap — where this Terraform gets written

## Credits

Built iteratively with [Claude](https://claude.ai) (Anthropic). Multi-AZ networking, ECS Fargate task definitions, IAM policy scoping, and ACM/Route 53 wiring all developed through pair-programming sessions with real `terraform plan` and `terraform apply` cycles against a live AWS account.

## License

MIT License — see [LICENSE](LICENSE).

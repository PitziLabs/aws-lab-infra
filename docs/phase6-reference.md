# Phase 6: CI/CD Pipeline — Reference Notes

## Status

**App deployment pipeline: ✅ COMPLETE and operational**
**Terraform infra pipeline: ⬜ Planned (Phase 6 part 2)**

First successful automated deployment: 2026-03-19

---

## Architecture Overview

```
Developer pushes to main (app/** changes)
        │
        ▼
GitHub Actions triggers
        │
        ▼
┌─────────────────────────────────┐
│  Clone cookbook recipes          │
│  (PitziLabs/ice-cream-book)     │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  Build Astro static site        │
│  Node 20 → npm ci → astro build│
│  (sync_recipes.py pulls content │
│   from ice-cream-book repo)     │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  OIDC Authentication            │
│  GitHub JWT → AWS STS           │
│  → Temporary credentials        │
│  (no stored secrets!)           │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  Docker Build                   │
│  Simple Dockerfile: copy dist/  │
│  into nginx (port 8080)         │
│  Tags: :latest + :<commit-sha>  │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  Push to ECR                    │
│  365184644049.dkr.ecr           │
│  .us-east-1.amazonaws.com       │
│  /aws-lab-dev-app               │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  ECS Rolling Deployment         │
│  1. New tasks start             │
│  2. ALB health checks pass      │
│  3. Old tasks drain             │
│  4. Zero downtime               │
│  5. Wait for stabilization      │
└─────────────────────────────────┘
           │
           ▼
    icecreamtofightover.com
```

## Key Resources

| Item | Value |
|------|-------|
| Workflow file | `.github/workflows/deploy.yml` |
| OIDC IAM Role | `aws-lab-dev-github-actions` |
| OIDC Role ARN | `arn:aws:iam::365184644049:role/aws-lab-dev-github-actions` |
| ECR Repository | `aws-lab-dev-app` |
| ECS Cluster | `aws-lab-dev-cluster` |
| ECS Service | `aws-lab-dev-app` |
| AWS Region | `us-east-1` |
| Live site | `https://icecreamtofightover.com` |
| Content source repo | `PitziLabs/ice-cream-book` |
| Infra repo | `PitziLabs/cloud-platform-demo` |

## How It Works — The Short Version

Push to `main` that touches `app/**` → GitHub Actions builds the Astro site from source, packages it in an nginx container, pushes to ECR, tells ECS to roll out a new deployment, and waits for it to stabilize. The whole thing takes about 2-3 minutes. OIDC means zero stored credentials — every run gets fresh temporary creds via a JWT token exchange.

## Build Architecture Decision: Why Astro Builds in CI, Not Docker

The Dockerfile is deliberately simple — it just copies pre-built static files into nginx. The Astro build happens in the GitHub Actions runner, not inside a multi-stage Docker build. This is intentional:

- **Better error messages** — if `npm ci` or `astro build` fails, you get clear CI output, not cryptic Docker build layer failures
- **Faster iteration** — Node dependencies are cached by `actions/setup-node`, so repeat builds are faster
- **Separation of concerns** — CI handles building, Docker handles packaging and serving
- **Simpler Dockerfile** — easier to debug, smaller attack surface

There IS a multi-stage Dockerfile at `app/ice_cream_site/Dockerfile` that does a self-contained build (Node + Astro inside Docker). That's useful for local development but is NOT what the pipeline uses.

## OIDC Authentication — How It Actually Works

1. GitHub Actions runner requests a JWT from `token.actions.githubusercontent.com`
2. The JWT includes claims: repo (`PitziLabs/cloud-platform-demo`), branch, workflow, actor
3. `aws-actions/configure-aws-credentials@v4` sends the JWT to AWS STS
4. AWS validates the JWT against our OIDC provider (created in Phase 2)
5. AWS checks the trust policy: `repo:PitziLabs/cloud-platform-demo:*`
6. STS issues temporary credentials scoped to the `aws-lab-dev-github-actions` role
7. Credentials expire when the workflow ends

**No secrets stored in GitHub. No keys to rotate. No long-lived credentials anywhere.**

The OIDC provider, IAM role, and trust policy all live in `modules/iam/main.tf`.

## Image Tagging Strategy

- **`:latest`** — Mutable tag, always points to the most recent build. Convenient for ECS to pull "whatever's newest."
- **`:<commit-sha>`** — Immutable tag tied to a specific git commit. The audit trail. If you need to know what's deployed, check the image tag on the running ECS task and match it to a commit.

The task definition references `:latest`, and we use `--force-new-deployment` to tell ECS to pull the new image. A future enhancement would be to update the task definition with the SHA tag for true immutability.

## Trigger Behavior

The workflow triggers on:
- **Push to `main`** that changes files in `app/**` or the workflow file itself
- **`workflow_dispatch`** — manual trigger from the GitHub Actions UI

The workflow does NOT trigger for:
- Changes to Terraform files (`.tf`) — that will be the infra pipeline
- Changes to documentation, README, etc.
- Pushes to non-main branches

## Deployment Mechanism

`aws ecs update-service --force-new-deployment` tells ECS to start a new deployment:

1. ECS launches new tasks using the current task definition (which pulls `:latest`)
2. New tasks register with the ALB target group
3. ALB runs health checks against `/health` endpoint on port 8080
4. Once healthy, ALB starts sending traffic to new tasks
5. Old tasks are deregistered from ALB (connection draining)
6. Old tasks are stopped
7. `aws ecs wait services-stable` blocks until rollout completes

**Zero downtime** — old tasks serve traffic until new ones are proven healthy.

## Troubleshooting

### OIDC "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Known issue**: IAM roles with "github" in the name can fail OIDC authentication due to a bug in `configure-aws-credentials`. Our role IS named `aws-lab-dev-github-actions`. If this breaks:
1. Rename the role in `modules/iam/main.tf` (e.g., `aws-lab-dev-cicd-deploy`)
2. `terraform apply`
3. Update the role ARN in `.github/workflows/deploy.yml`
4. See: https://github.com/aws-actions/configure-aws-credentials/issues/953

**As of 2026-03-19, this has NOT been an issue.** OIDC auth works fine. Documenting in case it crops up after a future AWS or GitHub change.

### Build fails — Docker context issues

The Docker build context is `app/` (not repo root). The simple Dockerfile expects:
- `nginx.conf` at `app/nginx.conf`
- Pre-built site at `app/ice_cream_site/dist/` (created by earlier CI steps)

If the build can't find files, check that the Astro build step actually produced output.

### ECS deployment not picking up new image

If ECS tasks are running but showing old content:
1. Verify image was pushed: `aws ecr describe-images --repository-name aws-lab-dev-app --profile aws-lab`
2. Check ECS events: `aws ecs describe-services --cluster aws-lab-dev-cluster --service aws-lab-dev-app --query 'services[0].events[:5]' --profile aws-lab`
3. Force manual redeploy: `aws ecs update-service --cluster aws-lab-dev-cluster --service aws-lab-dev-app --force-new-deployment --profile aws-lab`

### Recipe sync fails

The `sync_recipes.py` script reads from the `RECIPE_SOURCE` environment variable (set to `/tmp/ice-cream-book/recipes` in the workflow). If the `ice-cream-book` repo clone fails or the path changes, the build will produce an empty site.

### Deployment stabilization timeout

`aws ecs wait services-stable` has a ~10 minute timeout. If it times out:
- Check ECS events for task startup failures
- Verify the container health check is passing (GET /health on port 8080)
- Check CloudWatch logs for container errors
- Common cause: image exists but container crashes on startup (bad nginx config, missing dist/)

## Timing Baseline (2026-03-19)

| Step | Duration |
|------|----------|
| Set up job | 2s |
| Checkout infra repo | 4s |
| Clone cookbook recipes | 1s |
| Setup Node | 0s |
| Install Astro dependencies | 6s |
| Sync recipes | 1s |
| Build static site | 8s |
| Configure AWS credentials (OIDC) | 1s |
| Login to ECR | 1s |
| Build and push container image | 13s |
| Force new ECS deployment | 2s |
| Wait for deployment to stabilize | ~2-3 min |
| **Total** | **~3 min** |

## Commands Cheat Sheet

```bash
# Check what's currently deployed
aws ecs describe-services \
  --cluster aws-lab-dev-cluster \
  --service aws-lab-dev-app \
  --query 'services[0].deployments' \
  --profile aws-lab

# List recent images in ECR
aws ecr describe-images \
  --repository-name aws-lab-dev-app \
  --query 'sort_by(imageDetails, &imagePushedAt)[-5:].[imageTags, imagePushedAt]' \
  --profile aws-lab

# Force a manual redeploy
aws ecs update-service \
  --cluster aws-lab-dev-cluster \
  --service aws-lab-dev-app \
  --force-new-deployment \
  --profile aws-lab

# Watch deployment progress
watch -n 5 "aws ecs describe-services \
  --cluster aws-lab-dev-cluster \
  --service aws-lab-dev-app \
  --query 'services[0].deployments[*].[status, runningCount, desiredCount]' \
  --output table \
  --profile aws-lab"

# Check container logs
aws logs tail /ecs/aws-lab-dev-app --follow --profile aws-lab
```

## What's Next

- [ ] **Terraform infrastructure pipeline** — separate workflow for `plan`/`apply` on `.tf` changes
- [ ] **SHA-pinned task definitions** — update task def with exact SHA tag instead of `:latest`
- [ ] **Slack/email notifications** — alert on deployment success/failure
- [ ] **Rollback mechanism** — script to redeploy the previous SHA tag on failure
- [ ] **Branch protection + PR workflow** — require PR reviews, run `plan` on PR, `apply` on merge

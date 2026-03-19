terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "aws-lab"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "aws-lab"
      ManagedBy   = "terraform"
    }
  }
}
module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment

  availability_zones = ["us-east-1a", "us-east-1b"]

  # Using defaults for all CIDRs — override here if needed
}
data "aws_caller_identity" "current" {}

module "kms" {
  source = "../../modules/kms"

  environment    = var.environment
  project        = var.project
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region

  service_role_arns = [
    module.iam.ecs_task_execution_role_arn,
    module.iam.ecs_task_role_arn,
  ]
}
module "secrets" {
  source = "../../modules/secrets"

  environment = var.environment
  project     = var.project
  kms_key_arn = module.kms.key_arn
}
module "iam" {
  source = "../../modules/iam"

  environment               = var.environment
  project                   = var.project
  aws_account_id            = data.aws_caller_identity.current.account_id
  aws_region                = var.aws_region
  kms_key_arn               = module.kms.key_arn
  db_credentials_secret_arn = module.secrets.db_credentials_secret_arn
  github_org                = "cpitzi"
  github_repo               = "aws-lab-infra"

  # Phase 4: grant ECS roles access to RDS-managed secrets
  rds_managed_secret_access = true
}
module "security_groups" {
  source = "../../modules/security-groups"

  environment = var.environment
  project     = var.project
  vpc_id      = module.vpc.vpc_id
}
# --- Phase 3: Compute & Containers ---
module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
}

module "dns" {
  source = "../../modules/dns"

  project     = var.project
  environment = var.environment
  domain_name = "icecreamtofightover.com"

  subject_alternative_names = ["*.icecreamtofightover.com"]

  create_alb_alias = true
  alb_dns_name     = module.alb.alb_dns_name
  alb_zone_id      = module.alb.alb_zone_id
}
module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id
  certificate_arn   = module.dns.certificate_arn
}
module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  app_subnet_ids     = module.vpc.app_subnet_ids
  security_group_id  = module.security_groups.app_security_group_id
  target_group_arn   = module.alb.target_group_arn
  ecr_repository_url = module.ecr.repository_url

  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn
}
module "ecs_autoscaling" {
  source = "../../modules/ecs-autoscaling"

  project     = var.project
  environment = var.environment

  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  min_capacity = 2
  max_capacity = 6
}

# --- Phase 4: Data Layer ---
module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment

  data_subnet_ids       = module.vpc.data_subnet_ids
  rds_security_group_id = module.security_groups.rds_security_group_id
  kms_key_arn           = module.kms.key_arn
}
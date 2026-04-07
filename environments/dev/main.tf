# Dummy comment to test CI workflows — safe to remove
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
  github_org                = "PitziLabs"
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

module "s3" {
  source = "../../modules/s3"

  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arn

  # Phase 5: Service access for log delivery
  aws_account_id          = data.aws_caller_identity.current.account_id
  enable_cloudtrail_access = true
  cloudtrail_key_prefix   = "cloudtrail"
  enable_config_access    = true
  config_key_prefix       = "config"
}

module "elasticache" {
  source = "../../modules/elasticache"

  project     = var.project
  environment = var.environment

  data_subnet_ids         = module.vpc.data_subnet_ids
  redis_security_group_id = module.security_groups.redis_security_group_id
  kms_key_arn             = module.kms.key_arn
}

# --- Phase 5: Observability ---
module "monitoring" {
  source = "../../modules/monitoring"

  project     = var.project
  environment = var.environment

  alert_email = "cpitzi@gmail.com"

  # ECS dimensions
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  # ALB dimensions
  alb_arn_suffix         = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  # RDS dimensions
  rds_instance_id = module.rds.instance_id

  # ElastiCache dimensions
  elasticache_replication_group_id = module.elasticache.replication_group_id
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project     = var.project
  environment = var.environment

  s3_bucket_name = module.s3.bucket_id
  kms_key_arn    = module.kms.key_arn
}

module "aws_config" {
  source = "../../modules/aws-config"

  project     = var.project
  environment = var.environment

  s3_bucket_name = module.s3.bucket_id
  s3_key_prefix  = "config"
  sns_topic_arn  = module.monitoring.sns_topic_arn
}

moved {
  from = module.cloudtrail.aws_s3_bucket_policy.cloudtrail
  to   = module.s3.aws_s3_bucket_policy.this[0]
}

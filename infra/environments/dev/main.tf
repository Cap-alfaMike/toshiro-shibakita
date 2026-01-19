# =============================================================================
# Development Environment - Main Configuration
# Toshiro-Shibakita Infrastructure
# =============================================================================
# Cost-optimized for development:
# - Single NAT Gateway
# - No Multi-AZ for RDS
# - Smaller instance sizes
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "https://github.com/denilsonbonatti/toshiro-shibakita"
    }
  }
}

variable "project_name" {
  default = "toshiro-shibakita"
}

variable "environment" {
  default = "dev"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}

variable "api_image" {
  default = "nginx:alpine"  # Placeholder for dev
}

variable "frontend_image" {
  default = "nginx:alpine"  # Placeholder for dev
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# VPC (cost optimized - single NAT)
module "vpc" {
  source = "../../modules/vpc"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = var.availability_zones
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization
  enable_flow_logs   = false # Disable for dev
}

# KMS
module "kms" {
  source = "../../modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
}

# ALB
module "alb" {
  source = "../../modules/alb"
  
  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  enable_deletion_protection = false
  enable_access_logs         = false
}

# RDS (single AZ for dev)
module "rds" {
  source = "../../modules/rds"
  
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  isolated_subnet_ids   = module.vpc.isolated_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  db_instance_class     = "db.t4g.micro"
  multi_az              = false  # Cost optimization
  deletion_protection   = false
  kms_key_arn           = module.kms.key_arn
  
  depends_on = [module.ecs]
}

# ElastiCache
module "elasticache" {
  source = "../../modules/elasticache"
  
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  isolated_subnet_ids   = module.vpc.isolated_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  node_type             = "cache.t4g.micro"
  
  depends_on = [module.ecs]
}

# Secrets
module "secrets" {
  source = "../../modules/secrets"
  
  project_name     = var.project_name
  environment      = var.environment
  kms_key_arn      = module.kms.key_arn
  db_host          = module.rds.address
  db_port          = module.rds.port
  db_name          = module.rds.database_name
  db_username      = module.rds.username
  db_password      = module.rds.password
  redis_host       = module.elasticache.endpoint
  redis_port       = module.elasticache.port
  redis_auth_token = module.elasticache.auth_token
}

# CloudWatch
module "cloudwatch" {
  source = "../../modules/cloudwatch"
  
  project_name                = var.project_name
  environment                 = var.environment
  ecs_cluster_name            = module.ecs.cluster_name
  api_service_name            = module.ecs.api_service_name
  alb_arn_suffix              = regex("app/.*", module.alb.alb_arn)
  api_target_group_arn_suffix = regex("targetgroup/.*", module.alb.api_target_group_arn)
  rds_instance_id             = "${var.project_name}-${var.environment}-postgres"
  log_retention_days          = 7  # Shorter for dev
}

# ECS
module "ecs" {
  source = "../../modules/ecs"
  
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  alb_target_group_arn  = module.alb.api_target_group_arn
  api_image             = var.api_image
  frontend_image        = var.frontend_image
  secrets_arn           = module.secrets.secret_arn
  log_group_name        = module.cloudwatch.ecs_log_group_name
  api_cpu               = 256
  api_memory            = 512
  api_desired_count     = 1
  api_min_capacity      = 1
  api_max_capacity      = 2
  
  depends_on = [module.secrets, module.cloudwatch]
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

# =============================================================================
# Production Environment - Main Configuration
# Toshiro-Shibakita Infrastructure - Cloud-Native Evolution
# =============================================================================
# Original project: https://github.com/denilsonbonatti/toshiro-shibakita
# 
# This is the main entry point for deploying the production environment.
# Run with: terraform apply
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
  
  # Backend configuration for state management
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "toshiro-shibakita-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# =============================================================================
# Provider Configuration
# =============================================================================

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

# =============================================================================
# Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "toshiro-shibakita"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "api_image" {
  description = "API container image URI"
  type        = string
}

variable "frontend_image" {
  description = "Frontend container image URI"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = null
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = null
}

# =============================================================================
# Locals
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "https://github.com/denilsonbonatti/toshiro-shibakita"
  }
}

# =============================================================================
# KMS (Security)
# =============================================================================

module "kms" {
  source = "../modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# =============================================================================
# VPC (Network & Isolation Plane)
# =============================================================================

module "vpc" {
  source = "../modules/vpc"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = true
  single_nat_gateway = false  # Multi-AZ NAT for production
  enable_flow_logs   = true
  tags               = local.common_tags
}

# =============================================================================
# S3 Data Lake
# =============================================================================

module "s3" {
  source = "../modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  kms_key_arn  = module.kms.key_arn
  tags         = local.common_tags
}

# =============================================================================
# ALB (Edge & Traffic Management)
# =============================================================================

module "alb" {
  source = "../modules/alb"
  
  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = true
  enable_access_logs         = true
  access_logs_bucket         = module.s3.alb_logs_bucket_name
  tags                       = local.common_tags
}

# =============================================================================
# WAF (Security)
# =============================================================================

module "waf" {
  source = "../modules/waf"
  
  project_name = var.project_name
  environment  = var.environment
  scope        = "REGIONAL"
  alb_arn      = module.alb.alb_arn
  rate_limit   = 2000
  tags         = local.common_tags
}

# =============================================================================
# RDS (Data Plane)
# =============================================================================

module "rds" {
  source = "../modules/rds"
  
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  isolated_subnet_ids   = module.vpc.isolated_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  db_instance_class     = "db.t4g.medium"
  multi_az              = true
  deletion_protection   = true
  kms_key_arn           = module.kms.key_arn
  tags                  = local.common_tags
  
  depends_on = [module.ecs]
}

# =============================================================================
# ElastiCache (Data Plane)
# =============================================================================

module "elasticache" {
  source = "../modules/elasticache"
  
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  isolated_subnet_ids   = module.vpc.isolated_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  node_type             = "cache.t4g.micro"
  kms_key_arn           = module.kms.key_arn
  tags                  = local.common_tags
  
  depends_on = [module.ecs]
}

# =============================================================================
# Secrets Manager
# =============================================================================

module "secrets" {
  source = "../modules/secrets"
  
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
  tags             = local.common_tags
}

# =============================================================================
# ECS (Compute Plane)
# =============================================================================

module "ecs" {
  source = "../modules/ecs"
  
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
  api_cpu               = 512
  api_memory            = 1024
  frontend_cpu          = 256
  frontend_memory       = 512
  api_desired_count     = 2
  api_min_capacity      = 2
  api_max_capacity      = 10
  tags                  = local.common_tags
  
  depends_on = [module.secrets, module.cloudwatch]
}

# =============================================================================
# CloudWatch (Observabilidade)
# =============================================================================

module "cloudwatch" {
  source = "../modules/cloudwatch"
  
  project_name                = var.project_name
  environment                 = var.environment
  ecs_cluster_name            = "${var.project_name}-${var.environment}-cluster"
  api_service_name            = "${var.project_name}-${var.environment}-api"
  alb_arn_suffix              = regex("app/.*", module.alb.alb_arn)
  api_target_group_arn_suffix = regex("targetgroup/.*", module.alb.api_target_group_arn)
  rds_instance_id             = "${var.project_name}-${var.environment}-postgres"
  kms_key_arn                 = module.kms.key_arn
  log_retention_days          = 30
  tags                        = local.common_tags
}

# =============================================================================
# Outputs
# =============================================================================

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "api_endpoint" {
  description = "API endpoint"
  value       = "https://${module.alb.alb_dns_name}/api/v1"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.cloudwatch.dashboard_name
}

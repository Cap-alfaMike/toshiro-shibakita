# =============================================================================
# ElastiCache Module - Data Plane (Redis)
# Toshiro-Shibakita Infrastructure - Cloud-Native Evolution
# =============================================================================
# Implements Redis for:
# - Session caching
# - Query result caching
# - Rate limiting
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "isolated_subnet_ids" {
  description = "Isolated subnet IDs for ElastiCache"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS security group ID for Redis access"
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"  # Graviton2
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Locals
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "https://github.com/denilsonbonatti/toshiro-shibakita"
  })
}

# =============================================================================
# Random Auth Token
# =============================================================================

resource "random_password" "redis_auth" {
  length  = 32
  special = false  # Redis AUTH token doesn't support all special chars
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-sg"
  })
}

# =============================================================================
# Subnet Group
# =============================================================================

resource "aws_elasticache_subnet_group" "main" {
  name        = "${local.name_prefix}-redis-subnet-group"
  description = "Isolated subnet group for ElastiCache"
  subnet_ids  = var.isolated_subnet_ids
  
  tags = local.common_tags
}

# =============================================================================
# Parameter Group
# =============================================================================

resource "aws_elasticache_parameter_group" "main" {
  name        = "${local.name_prefix}-redis71-params"
  family      = "redis7"
  description = "Custom parameter group for Redis 7.1"
  
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  
  tags = local.common_tags
}

# =============================================================================
# ElastiCache Cluster
# =============================================================================

resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${local.name_prefix}-redis"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
  
  # Encryption
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  
  # Maintenance
  maintenance_window       = "Mon:05:00-Mon:06:00"
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "04:00-05:00"
  
  # Notifications
  notification_topic_arn = null
  
  apply_immediately = var.environment != "prod"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis"
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.main.port
}

output "auth_token" {
  description = "Redis auth token"
  value       = random_password.redis_auth.result
  sensitive   = true
}

output "security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}

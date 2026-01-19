# =============================================================================
# RDS Module - Data Plane (PostgreSQL)
# Toshiro-Shibakita Infrastructure - Cloud-Native Evolution
# =============================================================================
# Original project: Used MySQL with hardcoded credentials
# Evolution: PostgreSQL with Multi-AZ, encryption, and Performance Insights
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
  description = "Isolated subnet IDs for RDS"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS security group ID for database access"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "toshiro"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "toshiro_admin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"  # Graviton2
}

variable "db_allocated_storage" {
  description = "Initial allocated storage (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling (GB)"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
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
# Random Password Generation
# =============================================================================

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
  
  # No egress - isolated subnet, no internet access
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

# =============================================================================
# DB Subnet Group
# =============================================================================

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Isolated subnet group for RDS"
  subnet_ids  = var.isolated_subnet_ids
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# =============================================================================
# DB Parameter Group
# =============================================================================

resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-pg16-params"
  family      = "postgres16"
  description = "Custom parameter group for PostgreSQL 16"
  
  parameter {
    name  = "log_statement"
    value = "ddl"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries taking more than 1s
  }
  
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
  
  parameter {
    name  = "track_activity_query_size"
    value = "2048"
  }
  
  tags = local.common_tags
}

# =============================================================================
# RDS Instance
# =============================================================================

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"
  
  # Engine configuration
  engine               = "postgres"
  engine_version       = "16.1"
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.main.name
  
  # Storage configuration
  storage_type          = "gp3"
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage  # Auto-scaling
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn
  
  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432
  
  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # Isolated subnet
  
  # High availability
  multi_az = var.multi_az
  
  # Backup configuration
  backup_retention_period   = var.backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"
  skip_final_snapshot       = false
  
  # Monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = var.kms_key_arn
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  
  # Security
  deletion_protection      = var.deletion_protection
  iam_database_authentication_enabled = true
  
  # Updates
  auto_minor_version_upgrade = true
  apply_immediately          = false
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Enhanced Monitoring Role
# =============================================================================

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =============================================================================
# Outputs
# =============================================================================

output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Database username"
  value       = aws_db_instance.main.username
}

output "password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

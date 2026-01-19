# =============================================================================
# CloudWatch Module - Observabilidade & Operações
# Toshiro-Shibakita Infrastructure - Cloud-Native Evolution
# =============================================================================
# Implements:
# - CloudWatch Log Groups
# - Metric Alarms
# - Dashboards for infrastructure and business metrics
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

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "api_service_name" {
  description = "API service name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for metrics"
  type        = string
}

variable "api_target_group_arn_suffix" {
  description = "API target group ARN suffix"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "sns_alert_topic_arn" {
  description = "SNS topic ARN for alerts"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
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
# Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-logs"
  })
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/app/${local.name_prefix}/api"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-logs"
  })
}

# =============================================================================
# Metric Alarms - Infrastructure
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization is above 80%"
  alarm_actions       = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  ok_actions          = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${local.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS memory utilization is above 85%"
  alarm_actions       = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning 5XX errors"
  alarm_actions       = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${local.name_prefix}-alb-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2  # 2 seconds
  alarm_description   = "ALB target response time is above 2 seconds"
  alarm_actions       = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is above 80%"
  alarm_actions       = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${local.name_prefix}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "RDS connection count is above 100"
  alarm_actions       = var.sns_alert_topic_arn != null ? [var.sns_alert_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  
  tags = local.common_tags
}

# =============================================================================
# Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      # Row 1: ECS Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "ECS CPU Utilization"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.api_service_name]
          ]
          stat   = "Average"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "ECS Memory Utilization"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.api_service_name]
          ]
          stat   = "Average"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "ECS Running Tasks"
          region  = data.aws_region.current.name
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.api_service_name]
          ]
          stat   = "Average"
          period = 60
        }
      },
      # Row 2: ALB Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title   = "ALB Request Count"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
          stat   = "Sum"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title   = "ALB Response Time"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
          ]
          stat   = "Average"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title   = "ALB HTTP Errors"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_ELB_4XX_Count", ".", "."]
          ]
          stat   = "Sum"
          period = 60
        }
      },
      # Row 3: RDS Metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          title   = "RDS CPU Utilization"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          stat   = "Average"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          title   = "RDS Database Connections"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          stat   = "Average"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          title   = "RDS Read/Write IOPS"
          region  = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.rds_instance_id],
            [".", "WriteIOPS", ".", "."]
          ]
          stat   = "Average"
          period = 60
        }
      }
    ]
  })
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}

# =============================================================================
# Outputs
# =============================================================================

output "ecs_log_group_name" {
  description = "ECS log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "api_log_group_name" {
  description = "API log group name"
  value       = aws_cloudwatch_log_group.api.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

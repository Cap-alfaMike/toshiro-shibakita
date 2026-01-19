# =============================================================================
# WAF Module - Edge & Traffic Management Plane
# Toshiro-Shibakita Infrastructure - Cloud-Native Evolution
# =============================================================================
# Implements AWS WAF with:
# - AWS Managed Rules (Core, Known Bad Inputs, SQL Injection)
# - Rate limiting
# - IP reputation lists
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

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN (for CLOUDFRONT scope)"
  type        = string
  default     = null
}

variable "alb_arn" {
  description = "ALB ARN (for REGIONAL scope)"
  type        = string
  default     = null
}

variable "scope" {
  description = "WAF scope (REGIONAL or CLOUDFRONT)"
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "rate_limit" {
  description = "Rate limit per 5 minutes per IP"
  type        = number
  default     = 2000
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
# WAF Web ACL
# =============================================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${local.name_prefix}-waf"
  description = "WAF for Toshiro-Shibakita"
  scope       = var.scope
  
  default_action {
    allow {}
  }
  
  # Rule 1: AWS Managed - Core Rule Set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        
        # Exclude rules that might cause false positives
        rule_action_override {
          action_to_use {
            count {}
          }
          name = "SizeRestrictions_BODY"
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 2: AWS Managed - Known Bad Inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 3: AWS Managed - SQL Injection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 3
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 4: AWS Managed - IP Reputation
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 4
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 5: Rate Limiting
  rule {
    name     = "RateLimitRule"
    priority = 5
    
    action {
      block {
        custom_response {
          response_code = 429
          custom_response_body_key = "rate-limit-response"
        }
      }
    }
    
    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }
  
  custom_response_body {
    key          = "rate-limit-response"
    content      = jsonencode({ error = "Too many requests. Please try again later." })
    content_type = "APPLICATION_JSON"
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }
  
  tags = local.common_tags
}

# =============================================================================
# WAF Association
# =============================================================================

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.scope == "REGIONAL" && var.alb_arn != null ? 1 : 0
  
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# =============================================================================
# CloudWatch Log Group for WAF Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = 30
  
  tags = local.common_tags
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
  
  logging_filter {
    default_behavior = "DROP"
    
    filter {
      behavior = "KEEP"
      
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      
      requirement = "MEETS_ANY"
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "log_group_name" {
  description = "WAF log group name"
  value       = aws_cloudwatch_log_group.waf.name
}

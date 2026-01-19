# Architecture Diagrams

This directory contains architecture diagrams for the Toshiro-Shibakita project.

## Main Diagram

![AWS Architecture](aws-architecture.png)

## Components

**Edge Layer**: Route 53, CloudFront, WAF, ALB

**Compute Layer**: ECS Fargate running API and frontend containers in private subnets

**Data Layer**: RDS PostgreSQL and ElastiCache Redis in isolated subnets (no internet access)

**Security**: Secrets Manager, KMS encryption, VPC endpoints for private AWS API access

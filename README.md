# =============================================================================
# 🏯 Toshiro-Shibakita: Cloud-Native Evolution
# =============================================================================
#
# **Enterprise-Grade AWS Architecture | Senior Cloud Engineering Reference**
#
# [![AWS](https://img.shields.io/badge/AWS-Well--Architected-FF9900?logo=amazon-aws)](https://aws.amazon.com/architecture/well-architected/)
# [![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)](https://www.terraform.io/)
# [![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)](https://www.docker.com/)
# [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
#
# ---
#
# ## 📖 Sobre o Projeto
#
# Este repositório é uma **evolução cloud-native** do projeto original
# [denilsonbonatti/toshiro-shibakita](https://github.com/denilsonbonatti/toshiro-shibakita),
# elevando uma aplicação Docker básica para uma **arquitetura de referência de nível sênior**
# seguindo o **AWS Well-Architected Framework**.
#
# ### 🎯 Objetivo
#
# Demonstrar competências de **Staff/Principal Engineer** em:
# - Arquitetura cloud-native distribuída
# - Security-first design (Zero Trust)
# - Infrastructure as Code (Terraform)
# - Observabilidade em produção
# - CI/CD com deploy Blue/Green
#
# ---
#
# ## 🏗️ Arquitetura
#
# ```
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                           EDGE & TRAFFIC MANAGEMENT                          │
# │  ┌─────────┐    ┌─────────────┐    ┌─────────┐    ┌─────────────────────┐  │
# │  │Route 53 │───▶│ CloudFront  │───▶│ AWS WAF │───▶│ Application Load    │  │
# │  │  (DNS)  │    │   (CDN)     │    │(Security│    │ Balancer (Multi-AZ) │  │
# │  └─────────┘    └─────────────┘    └─────────┘    └──────────┬──────────┘  │
# └──────────────────────────────────────────────────────────────┼─────────────┘
#                                                                 │
# ┌──────────────────────────────────────────────────────────────┼─────────────┐
# │                         COMPUTE PLANE (PRIVATE SUBNETS)       │             │
# │                                                               ▼             │
# │    ┌──────────────────────────────────────────────────────────────────┐    │
# │    │                     ECS Fargate Cluster                          │    │
# │    │   ┌─────────────────┐         ┌─────────────────┐                │    │
# │    │   │   API Service   │         │ Frontend Service│                │    │
# │    │   │   (ARM64/Grav.) │         │   (Nginx/ARM64) │                │    │
# │    │   │   Auto-scaling  │         │                 │                │    │
# │    │   └────────┬────────┘         └─────────────────┘                │    │
# │    │            │                                                      │    │
# │    └────────────┼──────────────────────────────────────────────────────┘    │
# │                 │                                                           │
# └─────────────────┼───────────────────────────────────────────────────────────┘
#                   │
# ┌─────────────────┼───────────────────────────────────────────────────────────┐
# │                 │            DATA PLANE (ISOLATED SUBNETS)                  │
# │                 ▼                                                           │
# │    ┌─────────────────────┐         ┌─────────────────────┐                 │
# │    │    RDS PostgreSQL   │         │  ElastiCache Redis  │                 │
# │    │    (Multi-AZ)       │         │  (In-memory cache)  │                 │
# │    │    [Performance     │         │                     │                 │
# │    │     Insights]       │         │                     │                 │
# │    └─────────────────────┘         └─────────────────────┘                 │
# │                                                                             │
# │                        ┌─────────────────────┐                             │
# │                        │    S3 Data Lake     │                             │
# │                        │  [Parquet/Athena]   │                             │
# │                        └─────────────────────┘                             │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         SECURITY & GOVERNANCE (ZERO TRUST)                   │
# │                                                                              │
# │   ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │
# │   │ Secrets Manager│  │    AWS KMS     │  │ VPC Endpoints  │                │
# │   │ (Runtime Creds)│  │(CMK + Rotation)│  │ (Private Link) │                │
# │   └────────────────┘  └────────────────┘  └────────────────┘                │
# │                                                                              │
# │   ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │
# │   │  IAM Roles     │  │  Security      │  │    NACLs       │                │
# │   │(Task-specific) │  │  Groups        │  │  (Optional)    │                │
# │   └────────────────┘  └────────────────┘  └────────────────┘                │
# └─────────────────────────────────────────────────────────────────────────────┘
# ```
#
# ---
#
# ## 🗂️ Estrutura do Repositório
#
# ```
# toshiro-shibakita/
# ├── api/                          # Backend API (Node.js/TypeScript)
# │   ├── src/
# │   │   ├── config/               # Configuration management
# │   │   ├── database/             # PostgreSQL & Redis clients
# │   │   ├── middleware/           # Security middleware
# │   │   ├── routes/               # API routes
# │   │   ├── services/             # Business logic
# │   │   └── utils/                # Utilities (logger, etc.)
# │   ├── Dockerfile                # Multi-stage, ARM64 optimized
# │   └── package.json
# │
# ├── frontend/                     # Frontend (React/Vite + Nginx)
# │   ├── Dockerfile
# │   └── nginx.conf
# │
# ├── infra/                        # Terraform IaC
# │   ├── modules/
# │   │   ├── vpc/                  # VPC + Subnets + VPC Endpoints
# │   │   ├── ecs/                  # ECS Fargate + Auto Scaling
# │   │   ├── rds/                  # PostgreSQL Multi-AZ
# │   │   ├── alb/                  # Application Load Balancer
# │   │   ├── elasticache/          # Redis cluster
# │   │   ├── waf/                  # WAF + Managed Rules
# │   │   ├── s3/                   # Data Lake + ALB Logs
# │   │   ├── secrets/              # Secrets Manager
# │   │   ├── cloudwatch/           # Logs, Metrics, Dashboards
# │   │   └── iam/                  # KMS + IAM Roles
# │   └── environments/
# │       ├── dev/
# │       ├── staging/
# │       └── prod/
# │
# ├── ci-cd/
# │   └── pipeline.yml              # GitHub Actions pipeline
# │
# ├── scripts/
# │   └── init-db.sql               # Database initialization
# │
# ├── docker-compose.yml            # Local development
# └── README.md                     # This file
# ```
#
# ---
#
# ## 🚀 Quick Start
#
# ### Pré-requisitos
#
# - Docker & Docker Compose
# - Node.js 20+
# - Terraform 1.6+
# - AWS CLI v2 (configurado)
#
# ### Desenvolvimento Local
#
# ```bash
# # Clone o repositório
# git clone https://github.com/YOUR_USERNAME/toshiro-shibakita.git
# cd toshiro-shibakita
#
# # Suba o ambiente local
# docker-compose up -d
#
# # Acesse:
# # - Frontend: http://localhost
# # - API: http://localhost:3000
# # - Adminer (DB): http://localhost:8080
# # - Redis Commander: http://localhost:8081
# ```
#
# ### Deploy na AWS
#
# ```bash
# # Configure as credenciais AWS
# aws configure
#
# # Navegue para o ambiente desejado
# cd infra/environments/prod
#
# # Initialize Terraform
# terraform init
#
# # Review the plan
# terraform plan
#
# # Apply (isso criará toda a infraestrutura)
# terraform apply
# ```
#
# ---
#
# ## 🔐 Segurança (Zero Trust)
#
# ### Princípios Aplicados
#
# | Princípio | Implementação |
# |-----------|---------------|
# | **No hardcoded secrets** | AWS Secrets Manager com KMS |
# | **Least privilege** | IAM Task Roles específicas por serviço |
# | **Defense in depth** | WAF → ALB → Security Groups → NACLs |
# | **Encryption everywhere** | TLS 1.3 (ALB), KMS (RDS, S3, Secrets) |
# | **Network isolation** | Subnets Public/Private/Isolated |
# | **Private connectivity** | VPC Endpoints (sem internet) |
#
# ### Comparação: Original vs. Evolution
#
# | Aspecto | Original | Evolution |
# |---------|----------|-----------|
# | Credenciais | Hardcoded no PHP | Secrets Manager com rotação |
# | Banco de dados | MySQL sem SSL | PostgreSQL Multi-AZ + Encryption |
# | Rede | IPs hardcoded | VPC customizada com isolation |
# | Logs | Nenhum | CloudWatch com retenção |
# | Monitoramento | Nenhum | X-Ray + Dashboards + Alarmes |
#
# ---
#
# ## 📊 Observabilidade
#
# ### Stack de Observabilidade
#
# - **Logs**: CloudWatch Logs com JSON estruturado
# - **Metrics**: CloudWatch Metrics + ECS Container Insights
# - **Traces**: AWS X-Ray (OpenTelemetry)
# - **Dashboards**: CloudWatch Dashboard unificado
# - **Alertas**: CloudWatch Alarms → SNS
#
# ### Métricas Monitoradas
#
# - ECS CPU/Memory utilization
# - ALB latency e error rates (5XX, 4XX)
# - RDS connections e IOPS
# - Redis hit/miss ratio
# - Business metrics (registros criados/hora)
#
# ---
#
# ## 💰 Custos Estimados (us-east-1)
#
# | Recurso | Configuração | Custo Mensal (USD) |
# |---------|-------------|-------------------|
# | ECS Fargate | 2x API (0.5 vCPU, 1GB) | ~$36 |
# | RDS PostgreSQL | db.t4g.medium Multi-AZ | ~$120 |
# | ElastiCache | cache.t4g.micro | ~$13 |
# | ALB | Com 10GB processados | ~$22 |
# | NAT Gateway | 2x (Multi-AZ) | ~$65 |
# | CloudWatch | Logs + Metrics | ~$10 |
# | WAF | Web ACL + Rules | ~$12 |
# | **Total Estimado** | | **~$278/mês** |
#
# > ⚠️ Para reduzir custos em dev/staging:
# > - Use single NAT Gateway
# > - Desabilite Multi-AZ no RDS
# > - Use Fargate Spot
#
# ---
#
# ## 🔄 CI/CD Pipeline
#
# ```
# ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
# │   Build &   │───▶│  Security   │───▶│   Push to   │───▶│  Deploy to  │
# │    Test     │    │    Scan     │    │     ECR     │    │ ECS (B/G)   │
# │             │    │  (Trivy)    │    │             │    │             │
# └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
# ```
#
# ### Stages
#
# 1. **Build & Test**: Compila imagens Docker, executa testes
# 2. **Security Scan**: Trivy para vulnerabilidades (fail on HIGH/CRITICAL)
# 3. **Push to ECR**: Publica imagens no Amazon ECR
# 4. **Deploy**: Blue/Green deployment via ECS
# 5. **Rollback**: Automático se health check falhar
#
# ---
#
# ## 📐 Decisões Arquiteturais (ADRs)
#
# ### ADR-001: PostgreSQL ao invés de MySQL
#
# **Contexto**: O projeto original usava MySQL.
#
# **Decisão**: Migramos para PostgreSQL.
#
# **Justificativa**:
# - Melhor suporte a JSON e arrays
# - Performance Insights nativo no RDS
# - Melhor compatibilidade com pg_stat_statements
# - Comunidade mais ativa para cloud-native
#
# ### ADR-002: Node.js/TypeScript ao invés de PHP
#
# **Contexto**: Aplicação original em PHP vanilla.
#
# **Decisão**: Reescrita em Node.js/TypeScript.
#
# **Justificativa**:
# - Melhor suporte a async/await para I/O
# - Ecossistema rico (OpenTelemetry, AWS SDK v3)
# - Type safety com TypeScript
# - Melhor performance para APIs JSON
#
# ### ADR-003: ARM64 (Graviton) ao invés de x86
#
# **Contexto**: Choice of compute architecture.
#
# **Decisão**: ARM64 com Graviton3.
#
# **Justificativa**:
# - ~40% melhor preço/performance
# - Menor consumo de energia
# - Suporte nativo no ECS Fargate
#
# ---
#
# ## 🔮 Próximos Passos
#
# ### Fase 2 (Planejado)
#
# - [ ] CloudFront distribution com certificate ACM
# - [ ] Route 53 com health checks
# - [ ] Secret rotation com Lambda
# - [ ] Terraform remote state com S3 + DynamoDB lock
# - [ ] Multi-region DR (pilot light)
#
# ### Fase 3 (Futuro)
#
# - [ ] Service mesh com AWS App Mesh
# - [ ] Event-driven com EventBridge
# - [ ] API Gateway com throttling
# - [ ] Chaos engineering com AWS FIS
#
# ---
#
# ## 👥 Créditos
#
# Este projeto é uma evolução do trabalho original de **Denilson Bonatti**:
#
# > 🔗 **Repositório Original**: [denilsonbonatti/toshiro-shibakita](https://github.com/denilsonbonatti/toshiro-shibakita)
# >
# > *"Docker: Utilização prática no cenário de Microsserviços"*
# > — Denilson Bonatti, Instrutor Digital Innovation One
#
# ### Evolução Arquitetural
#
# | Original | Evolution |
# |----------|-----------|
# | Docker básico | ECS Fargate Multi-AZ |
# | MySQL local | RDS PostgreSQL Multi-AZ |
# | Nginx LB hardcoded | ALB + WAF + CloudFront |
# | Sem IaC | Terraform modular |
# | Sem CI/CD | GitHub Actions (Blue/Green) |
#
# ---
#
# ## 📄 Licença
#
# MIT License - Veja [LICENSE](LICENSE) para detalhes.
#
# ---
#
# <div align="center">
#
# **🏯 Toshiro-Shibakita: Cloud-Native Evolution**
#
# *De um container simples a uma arquitetura enterprise-grade*
#
# [⬆ Voltar ao topo](#-toshiro-shibakita-cloud-native-evolution)
#
# </div>

# =============================================================================
# Multi-stage Dockerfile for Toshiro-Shibakita Frontend
# Optimized for AWS ECS Fargate with ARM64 (Graviton3)
# =============================================================================
# Original project: https://github.com/denilsonbonatti/toshiro-shibakita
# Evolution: Modern React frontend with optimized nginx serving
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Dependencies
# -----------------------------------------------------------------------------
FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./
RUN npm ci && npm cache clean --force

# -----------------------------------------------------------------------------
# Stage 2: Builder
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build production bundle
ENV NODE_ENV=production
RUN npm run build

# -----------------------------------------------------------------------------
# Stage 3: Production (nginx)
# -----------------------------------------------------------------------------
FROM nginx:1.25-alpine AS production

LABEL maintainer="Cloud Architecture Team" \
    version="2.0.0" \
    description="Toshiro-Shibakita Frontend - Cloud-Native Evolution" \
    original.project="https://github.com/denilsonbonatti/toshiro-shibakita"

# Install security updates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built static files
COPY --from=builder /app/dist /usr/share/nginx/html

# Create non-root user for nginx
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Run as non-root
USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

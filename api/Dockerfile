# =============================================================================
# Multi-stage Dockerfile for Toshiro-Shibakita API
# Optimized for AWS ECS Fargate with ARM64 (Graviton3)
# Following AWS Well-Architected Framework best practices
# =============================================================================
# Original project: https://github.com/denilsonbonatti/toshiro-shibakita
# Evolution: Cloud-native architecture with security-first approach
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Dependencies (cached layer for faster builds)
# -----------------------------------------------------------------------------
FROM node:20-alpine AS deps

# Security: Run as non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy package files for dependency caching
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# -----------------------------------------------------------------------------
# Stage 2: Builder (compile TypeScript)
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source code
COPY src/ ./src/

# Build TypeScript
RUN npm run build

# -----------------------------------------------------------------------------
# Stage 3: Production (minimal image)
# -----------------------------------------------------------------------------
FROM node:20-alpine AS production

# Security labels
LABEL maintainer="Cloud Architecture Team" \
      version="2.0.0" \
      description="Toshiro-Shibakita API - Cloud-Native Evolution" \
      original.project="https://github.com/denilsonbonatti/toshiro-shibakita"

# Security: Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Install security updates and minimal dependencies
RUN apk update && \
    apk upgrade && \
    apk add --no-cache dumb-init curl && \
    rm -rf /var/cache/apk/*

WORKDIR /app

# Copy production dependencies from deps stage
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built application from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Security: Switch to non-root user
USER nodejs

# Health check configuration
# ECS will use this for container health monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Expose port (configurable via environment variable)
EXPOSE 3000

# Environment defaults (will be overridden by ECS task definition)
ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info

# Use dumb-init for proper signal handling (graceful shutdown)
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "dist/server.js"]

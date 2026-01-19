# Multi-stage build for Node.js API
# Optimized for ECS Fargate ARM64

# Stage 1: Dependencies
FROM node:20-alpine AS deps

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Build
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci
COPY src/ ./src/
RUN npm run build

# Stage 3: Production
FROM node:20-alpine AS production

LABEL maintainer="Cloud Architecture Team" \
    original.project="https://github.com/denilsonbonatti/toshiro-shibakita"

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
RUN apk update && apk upgrade && apk add --no-cache dumb-init curl && rm -rf /var/cache/apk/*

WORKDIR /app

COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

USER nodejs

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

EXPOSE 3000

ENV NODE_ENV=production PORT=3000 LOG_LEVEL=info

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]

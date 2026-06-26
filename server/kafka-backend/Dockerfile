# ============================================================
# Dockerfile — NestJS Kafka Backend
# Multi-stage build for production-ready container images.
# ============================================================

# ---- Build Stage ----
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files and install dependencies
COPY package.json tsconfig.json nest-cli.json ./
RUN npm ci --only=production --ignore-scripts
RUN npm ci --only=development --ignore-scripts

# Copy source code
COPY src/ ./src/

# Build the application
RUN npm run build

# Prune dev dependencies
RUN npm prune --production

# ---- Production Stage ----
FROM node:20-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built artifacts from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# Set ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/transfers || exit 1

CMD ["node", "dist/main.js"]

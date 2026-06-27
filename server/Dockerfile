# syntax=docker/dockerfile:1
# Dockerfile for INT Bank Backend (NestJS)
# Multi-stage build: compiles TS then runs the compiled JS

# --- Builder Stage ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copy NestJS project files
COPY kafka-backend/package*.json kafka-backend/tsconfig.json kafka-backend/nest-cli.json ./
RUN npm ci --ignore-scripts

# Copy source TypeScript
COPY kafka-backend/src/ ./src/

# Compile TypeScript → dist/
RUN npm run build

# --- Production Stage ---
FROM node:20-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy production dependencies
COPY kafka-backend/package*.json ./
RUN npm ci --only=production --ignore-scripts

# Copy compiled output from builder
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist

# Copy runtime assets (certs, .env, etc.)
COPY --chown=appuser:appgroup .env* ./kafka-backend/.env* ./

# Use non-root user
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["node", "dist/main.js"]

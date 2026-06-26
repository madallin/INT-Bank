# syntax=docker/dockerfile:1
# Dockerfile for INT Bank Backend (Node.js + Express + TypeScript)
# Multi-stage build: compiles TS then runs the compiled JS

# --- Builder Stage ---
FROM node:20-alpine AS builder

WORKDIR /app

# Install ALL dependencies (including devDependencies for tsc)
COPY package*.json tsconfig.json ./
RUN npm ci

# Copy source TypeScript
COPY src/ ./src/

# Compile TypeScript → dist/
RUN npm run build

# --- Production Stage ---
FROM node:20-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy compiled output from builder
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist

# Copy runtime assets (certs, .env, etc.)
COPY --chown=appuser:appgroup .env* ./

# Use non-root user
USER appuser

EXPOSE 8443

CMD ["node", "dist/index.js"]

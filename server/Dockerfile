# syntax=docker/dockerfile:1
# Dockerfile for INT Bank Backend (Node.js + Express)

FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies first (cache optimization)
COPY package*.json ./
RUN npm ci --only=production

# --- Production Stage ---
FROM node:18-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy production dependencies
COPY --from=builder /app/node_modules ./node_modules

# Copy application source code
COPY . .

# Set proper ownership
RUN chown -R appuser:appgroup /app

# Use non-root user
USER appuser

# Expose API port
EXPOSE 8443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-check-certificate --spider https://localhost:8443/health || exit 1

# Start the server
CMD ["node", "index.js"]

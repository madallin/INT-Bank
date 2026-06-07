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

# Copy production dependencies (și le dăm direct drepturi utilizatorului non-root)
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy application source code (și le dăm direct drepturi utilizatorului non-root)
COPY --chown=appuser:appgroup . .

# Use non-root user
USER appuser

EXPOSE 8080

CMD ["node", "index.js"]
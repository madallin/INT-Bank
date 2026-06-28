# syntax=docker/dockerfile:1
# Single Dockerfile for INT Bank Backend (NestJS)

FROM node:20-alpine AS builder

WORKDIR /app

COPY kafka-backend/package*.json kafka-backend/tsconfig.json kafka-backend/nest-cli.json ./
RUN npm ci --ignore-scripts

COPY kafka-backend/src/ ./src/

RUN npm run build

FROM node:20-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY kafka-backend/package*.json ./
RUN npm ci --only=production --ignore-scripts

COPY --from=builder --chown=appuser:appgroup /app/dist ./dist

USER appuser

CMD node dist/main.js

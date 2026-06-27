FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json tsconfig.json nest-cli.json ./
COPY src/ ./src/

RUN npm ci --ignore-scripts && npm run build

FROM node:20-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY package.json ./
RUN npm ci --only=production --ignore-scripts

COPY --from=builder --chown=appuser:appgroup /app/dist ./dist

USER appuser

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/transfers || exit 1

CMD ["node", "dist/main.js"]

# syntax=docker/dockerfile:1
# Multi-stage Dockerfile for INT Bank Backend (Spring Boot + Java 21)

FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

COPY backend/pom.xml .
COPY backend/src/ src/

RUN apk add --no-cache maven && \
    mvn package -DskipTests -q && \
    cp target/*.jar app.jar

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder --chown=appuser:appgroup /app/app.jar ./app.jar

USER appuser

EXPOSE 8443 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8443/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
# ---- Stage 1: build the Spring Boot executable JAR ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# Cache Maven dependencies first (only re-downloaded when pom.xml changes).
# Paths are relative to the build context. Render uses "server" as the context,
# so the Maven project lives under backend/.
COPY backend/pom.xml .
RUN mvn -B -e -q dependency:go-offline || true

COPY backend/src ./src
RUN mvn -B -e clean package -DskipTests

# ---- Stage 2: minimal runtime image ----
# Alpine has a smaller runtime footprint and avoids the Ubuntu pebble Go binary.
FROM eclipse-temurin:25-jre-alpine

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/urandom"

# Retain PID 1 signal handling and the existing healthcheck without apt/Ubuntu.
# Upgrade preinstalled packages (including libexpat) before adding runtime tools.
RUN apk upgrade --no-cache \
    && apk add --no-cache dumb-init curl ca-certificates \
    && addgroup -S app \
    && adduser -S -D -H -u 10001 -G app app

WORKDIR /app

# Single executable jar (the *.original repackage backup is not matched by *.jar)
COPY --from=build /workspace/target/*.jar /app/app.jar
COPY backend/docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh
RUN chown -R app:app /app

USER 10001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8080}/actuator/health/liveness || exit 1

# dumb-init becomes PID 1 and reaps zombies / proxies SIGTERM to the JVM.
# The entrypoint script imports Aiven's CA (if provided) before launching the app.
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/app/docker-entrypoint.sh"]

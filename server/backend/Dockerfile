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
FROM eclipse-temurin:21-jre

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/urandom"

# dumb-init forwards signals (SIGTERM) to the JVM for clean graceful shutdown;
# curl is used only by the container healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends dumb-init curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r app && useradd -r -u 10001 -g app app

WORKDIR /app

# Single executable jar (the *.original repackage backup is not matched by *.jar)
COPY --from=build /workspace/target/*.jar /app/app.jar
RUN chown -R app:app /app

USER 10001

EXPOSE 8443

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8443}/actuator/health/liveness || exit 1

# dumb-init becomes PID 1 and reaps zombies / proxies SIGTERM to the JVM.
# exec ensures the JVM replaces the shell so it receives the signal directly.
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]

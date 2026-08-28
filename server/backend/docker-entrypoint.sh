#!/bin/sh
set -e

# If Aiven's CA is provided (base64-encoded), import it into a copy of the JVM
# truststore so Kafka TLS succeeds while keeping the default public CAs trusted
# for other outbound HTTPS calls (Twilio, Geoapify, etc.).
if [ -n "$KAFKA_CA_PEM_B64" ]; then
  echo "$KAFKA_CA_PEM_B64" | base64 -d > /app/aiven-ca.pem
  cp "$JAVA_HOME/lib/security/cacerts" /app/aiven-truststore.jks
  if ! keytool -list -alias aiven-ca -keystore /app/aiven-truststore.jks -storepass changeit >/dev/null 2>&1; then
    keytool -import -alias aiven-ca -file /app/aiven-ca.pem \
      -keystore /app/aiven-truststore.jks -storepass changeit -noprompt
  fi
  export JAVA_OPTS="$JAVA_OPTS -Djavax.net.ssl.trustStore=/app/aiven-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
fi

exec java $JAVA_OPTS -jar /app/app.jar "$@"

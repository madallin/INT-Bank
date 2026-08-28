#!/bin/sh
set -e

CA_PEM=""
if [ -n "$KAFKA_CA_PEM_B64" ]; then
  CA_PEM=$(echo "$KAFKA_CA_PEM_B64" | base64 -d)
elif [ -n "$KAFKA_CA_PEM" ]; then
  CA_PEM="$KAFKA_CA_PEM"
fi

if [ -n "$CA_PEM" ]; then
  echo "$CA_PEM" > /app/aiven-ca.pem
  cp "$JAVA_HOME/lib/security/cacerts" /app/aiven-truststore.jks
  if ! keytool -list -alias aiven-ca -keystore /app/aiven-truststore.jks -storepass changeit >/dev/null 2>&1; then
    keytool -import -alias aiven-ca -file /app/aiven-ca.pem -keystore /app/aiven-truststore.jks -storepass changeit -noprompt
  fi
  export JAVA_OPTS="$JAVA_OPTS -Djavax.net.ssl.trustStore=/app/aiven-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
  echo "[entrypoint] Aiven CA imported into JVM truststore"
else
  echo "[entrypoint] No KAFKA_CA_PEM / KAFKA_CA_PEM_B64 provided; using default JVM truststore"
fi

exec java $JAVA_OPTS -jar /app/app.jar "$@"

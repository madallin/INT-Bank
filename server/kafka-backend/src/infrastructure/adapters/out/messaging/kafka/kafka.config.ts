// ============================================================
// Kafka Configuration Helper
// Hexagonal Architecture — Infrastructure Layer
//
// Builds the KafkaJS config (brokers, SSL, SASL) from env vars.
// Supports three authentication modes:
//   1. None (localhost)          — ssl: false
//   2. SSL certificates          — ssl: { ca, cert, key }
//   3. SASL (username/password)  — ssl: true + sasl: { ... }
// ============================================================

import { logLevel as KafkaLogLevel } from 'kafkajs';

/**
 * Replace literal '\n' strings with actual newlines.
 * This is needed because multi-line certificates stored in
 * .env files or Render env vars often have \n as literal text.
 */
function normalizeCert(value: string | undefined): string {
  return value?.replace(/\\n/g, '\n') ?? '';
}

/**
 * Build the `ssl` option for KafkaJS based on env vars.
 *
 * Priority:
 *   1. If KAFKA_SSL_ACCESS_KEY is set → use certificate-based SSL
 *   2. Else if KAFKA_SASL_USERNAME is set → enable SSL (for SASL)
 *   3. Else → no SSL
 */
export function getKafkaSslConfig():
  | boolean
  | { rejectUnauthorized: boolean; ca: string[]; cert: string; key: string } {
  const accessKey = process.env.KAFKA_SSL_ACCESS_KEY;

  if (accessKey) {
    return {
      rejectUnauthorized: false,
      ca: [normalizeCert(process.env.KAFKA_SSL_CA_CERT)],
      cert: normalizeCert(process.env.KAFKA_SSL_ACCESS_CERT),
      key: normalizeCert(accessKey),
    };
  }

  if (process.env.KAFKA_SASL_USERNAME) {
    return true;
  }

  return false;
}

/**
 * Build the `sasl` option for KafkaJS based on env vars.
 * Returns undefined if no SASL credentials are configured.
 */
export function getKafkaSaslConfig():
  | { mechanism: 'plain'; username: string; password: string }
  | undefined {
  const username = process.env.KAFKA_SASL_USERNAME;
  if (!username) return undefined;

  return {
    mechanism: 'plain',
    username,
    password: process.env.KAFKA_SASL_PASSWORD ?? '',
  };
}

/**
 * Get the list of Kafka brokers from env.
 */
export function getKafkaBrokers(): string[] {
  return (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
}

/**
 * Common KafkaJS client configuration used by both producer and consumer.
 */
export function getKafkaClientConfig(clientId: string) {
  return {
    clientId,
    brokers: getKafkaBrokers(),
    logLevel: KafkaLogLevel.INFO,
    retry: {
      initialRetryTime: 300,
      retries: 10,
      maxRetryTime: 30000,
    },
    ssl: getKafkaSslConfig(),
    ...(getKafkaSaslConfig()
      ? { sasl: getKafkaSaslConfig() }
      : {}),
  };
}

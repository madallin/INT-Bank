import { logLevel as KafkaLogLevel } from 'kafkajs';

function normalizeCert(value: string | undefined): string
{
  return value?.replace(/\\n/g, '\n') ?? '';
}

export function getKafkaSslConfig():
  | boolean
  | { rejectUnauthorized: boolean; ca: string[]; cert: string; key: string }
{
  const accessKey = process.env.KAFKA_SSL_ACCESS_KEY;

  if(accessKey)
  {
    return {
      rejectUnauthorized: false,
      ca: [normalizeCert(process.env.KAFKA_SSL_CA_CERT)],
      cert: normalizeCert(process.env.KAFKA_SSL_ACCESS_CERT),
      key: normalizeCert(accessKey),
    };
  }

  if(process.env.KAFKA_SASL_USERNAME)
  {
    return true;
  }

  return false;
}

export function getKafkaSaslConfig():
  | { mechanism: 'plain'; username: string; password: string }
  | undefined
{
  const username = process.env.KAFKA_SASL_USERNAME;
  if(!username) return undefined;

  return {
    mechanism: 'plain',
    username,
    password: process.env.KAFKA_SASL_PASSWORD ?? '',
  };
}

export function getKafkaBrokers(): string[]
{
  return (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
}

export function getKafkaClientConfig(clientId: string)
{
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

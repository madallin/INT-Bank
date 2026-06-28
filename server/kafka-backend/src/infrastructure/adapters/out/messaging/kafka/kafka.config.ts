import { logLevel as KafkaLogLevel } from 'kafkajs';
import * as fs from 'fs';
import * as path from 'path';

function loadCert(fileName: string): string
{
  const productionPath = path.join('/etc/secrets', fileName);
  const localPath = path.join(__dirname, '..', '..', '..', '..', '..', '..', '..', 'certs', fileName);

  if(fs.existsSync(productionPath))
  {
    return fs.readFileSync(productionPath, 'utf-8');
  }

  if(fs.existsSync(localPath))
  {
    return fs.readFileSync(localPath, 'utf-8');
  }

  return '';
}

export function getKafkaSslConfig():
  | boolean
  | { rejectUnauthorized: boolean; ca: string[]; cert: string; key: string }
{
  const caCert   = loadCert('ca.pem');
  const cert     = loadCert('service.cert');
  const key      = loadCert('service.key');

  // Daca avem certificate citite de pe disc, le folosim
  if(caCert && cert && key)
  {
    return {
      rejectUnauthorized: false,
      ca: [caCert],
      cert,
      key,
    };
  }

  // Fallback: citeste din variabile de mediu (compatibilitate)
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

function normalizeCert(value: string | undefined): string
{
  return value?.replace(/\\n/g, '\n') ?? '';
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

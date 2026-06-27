import Redis from 'ioredis';
import { logger } from './logger';

const redis = new Redis(
{
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT, 10) : 6379,
    password: process.env.REDIS_PASSWORD,
    tls: {} as any,
    maxRetriesPerRequest: null,
} as any);

redis.on('connect', () => logger.info('Connected to Redis!'));
redis.on('error', (err: Error) => logger.error(err, 'Redis error:'));

export { redis };

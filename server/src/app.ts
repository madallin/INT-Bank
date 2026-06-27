import express, { Application, Request, Response } from 'express';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { AppDataSource } from './config/database';
import { redis } from './config/redis';
import { logger } from './config/logger';
import authRoutes from './routes/auth.routes';

const app: Application = express();

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

app.locals.redis = redis;

app.use(
    pinoHttp(
    {
        logger,
        autoLogging:
        {
            ignore: (req) => req.url === '/health' || req.url === '/express_status',
        },
    }));

app.use((req, _res, next) =>
{
    (req as any).dataSource = AppDataSource;
    next();
});

app.get('/express_status', (_req: Request, res: Response) => res.json({ status: 'ok' }));
app.get('/health', (_req: Request, res: Response) => res.json({ status: 'ok' }));

app.use('/', authRoutes);

export default app;

import dotenv from 'dotenv';
dotenv.config();

import http from 'http';
import { setupWebSocket } from './websocket/handler';
import { AppDataSource } from './config/database';
import { redis } from './config/redis';
import { logger } from './config/logger';
import app from './app';

const PORT = process.env.PORT || 8080;

async function bootstrap(): Promise<void>
{
    try
    {
        await AppDataSource.initialize();
        logger.info('TypeORM DataSource initialized successfully');
    }
    catch(error)
    {
        logger.error(error, 'Failed to initialize TypeORM DataSource');
        process.exit(1);
    }

    const server = http.createServer(app);

    server.listen(PORT, () =>
    {
        logger.info(`Server started on port ${PORT}`);
    });

    const { pgClient } = setupWebSocket(server);

    const shutdown = async () =>
    {
        logger.info('Shutting down server...');
        try
        {
            await AppDataSource.destroy();
        }
        catch(e)
        {
            logger.error(e, 'Error closing TypeORM connection');
        }
        try
        {
            await redis.quit();
        }
        catch(e)
        {
            /* ignore */
        }
        try
        {
            await pgClient.end();
        }
        catch(e)
        {
            /* ignore */
        }
        server.close(() => process.exit(0));
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
}

bootstrap().catch((error) =>
{
    logger.error(error, 'Failed to bootstrap application');
    process.exit(1);
});

import pino from 'pino';
import path from 'path';

const isProduction = process.env.NODE_ENV === 'production';

const transport = isProduction
    ? pino.transport(
    {
        targets: [
            {
                target: 'pino/file',
                options:
                {
                    destination: path.join(__dirname, '../../logs/app.log'),
                    mkdir: true,
                },
            },
            {
                target: 'pino/file',
                options:
                {
                    destination: 1, // stdout
                },
            },
        ],
    })
    : pino.transport(
    {
        target: 'pino/file',
        options:
        {
            destination: 1, // stdout only in dev
        },
    });

export const logger = pino(
{
    level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
    formatters:
    {
        level(label: string)
        {
            return { level: label };
        },
    },
    serializers:
    {
        err: pino.stdSerializers.err,
        req: pino.stdSerializers.req,
        res: pino.stdSerializers.res,
    },
    timestamp: pino.stdTimeFunctions.isoTime,
}, transport);

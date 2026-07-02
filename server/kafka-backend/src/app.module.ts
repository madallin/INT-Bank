import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_PIPE } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';

import { InfrastructureModule } from './infrastructure/infrastructure.module';
import { ApplicationModule } from './application/application.module';
import { AllExceptionsFilter } from './infrastructure/common/filters/http-exception.filter';
import { HmacGuard } from './infrastructure/common/guards/hmac.guard';

const isProduction = process.env.NODE_ENV === 'production';
const hmacEnabled = process.env.HMAC_ENABLED !== 'false';

@Module({
  imports: [
    ThrottlerModule.forRoot({
      throttlers: [
        {
          ttl: 60000,
          limit: 100,
        },
      ],
    }),
    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
        transport:
          isProduction
            ? {
                targets: [
                  {
                    target: 'pino/file',
                    options: { destination: './logs/app.log', mkdir: true },
                  },
                  {
                    target: 'pino/file',
                    options: { destination: 1 },
                  },
                ],
              }
            : {
                target: 'pino/file',
                options: { destination: 1 },
              },
        serializers: {
          req: (req) => ({
            method: req.method,
            url: req.url,
            headers: { 'user-agent': req.headers?.['user-agent'] },
          }),
          res: (res) => ({
            statusCode: res.statusCode,
          }),
        },
        autoLogging: {
          ignore: (req) => req.url === '/health',
        },
      },
    }),
    ApplicationModule,
    InfrastructureModule,
  ],
  providers: [
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    ...(hmacEnabled
      ? [
          {
            provide: APP_GUARD,
            useClass: HmacGuard,
          } as const,
        ]
      : []),
    {
      provide: APP_PIPE,
      useFactory: () =>
        new ValidationPipe({
          whitelist: true,
          forbidNonWhitelisted: true,
          transform: true,
          transformOptions: {
            enableImplicitConversion: false,
          },
        }),
    },
  ],
})
export class AppModule {}

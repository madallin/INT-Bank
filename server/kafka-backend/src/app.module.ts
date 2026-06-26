// ============================================================
// Root App Module
// Hexagonal Architecture — Composition Root
// Wires together all layers with strict dependency direction:
//   Infrastructure → Application → Core Domain
// ============================================================

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE, APP_INTERCEPTOR } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';

import { InfrastructureModule } from './infrastructure/infrastructure.module';
import { ApplicationModule } from './application/application.module';
import { AllExceptionsFilter } from './infrastructure/common/filters/http-exception.filter';
import { LoggingInterceptor } from './infrastructure/common/interceptors/logging.interceptor';

@Module({
  imports: [
    ApplicationModule,
    InfrastructureModule,
  ],
  providers: [
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
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
    {
      provide: APP_INTERCEPTOR,
      useClass: LoggingInterceptor,
    },
  ],
})
export class AppModule {}

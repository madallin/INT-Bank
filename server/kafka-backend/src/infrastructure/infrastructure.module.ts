import { Module } from '@nestjs/common';

import { DatabaseModule } from './adapters/out/persistence/typeorm/database.module';
import { KafkaModule } from './adapters/out/messaging/kafka/kafka.module';
import { ApplicationModule } from '../application/application.module';

import { TransferController } from './adapters/in/rest/transfer.controller';
import { UsersController } from './adapters/in/rest/users.controller';
import { AuthController } from './adapters/in/rest/auth.controller';
import { LoginController } from './adapters/in/rest/login.controller';
import { TwoFAController } from './adapters/in/rest/two-fa.controller';
import { PlacesController } from './adapters/in/rest/places.controller';
import { RegisterController } from './adapters/in/rest/register.controller';
import { CurrencyController } from './adapters/in/rest/currency.controller';
import { AuthSessionController } from './adapters/in/rest/auth-session.controller';
import { HealthController } from './adapters/in/rest/health.controller';

import { BankingService } from './services/banking.service';
import { ApprovalWsGateway } from './adapters/in/websocket/approval-ws.gateway';
import { CryptoService } from './services/crypto.service';
import { CurrencyService } from './services/currency.service';

import { ClientTokenGuard } from './common/guards/client-token.guard';
import { UserTokenGuard } from './common/guards/user-token.guard';
import { HmacGuard } from './common/guards/hmac.guard';

@Module({
  imports: [
    DatabaseModule,
    KafkaModule,
    ApplicationModule,
  ],
  controllers: [
    TransferController,
    UsersController,
    AuthController,
    LoginController,
    TwoFAController,
    PlacesController,
    RegisterController,
    CurrencyController,
    AuthSessionController,
    HealthController,
  ],
  providers: [
    BankingService,
    ApprovalWsGateway,
    CryptoService,
    CurrencyService,
    ClientTokenGuard,
    UserTokenGuard,
    HmacGuard,
  ],
  exports: [
    HmacGuard,
  ],
})
export class InfrastructureModule {}

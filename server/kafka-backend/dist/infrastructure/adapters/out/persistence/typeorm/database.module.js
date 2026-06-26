"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DatabaseModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const account_orm_entity_1 = require("./entities/account.orm-entity");
const transfer_orm_entity_1 = require("./entities/transfer.orm-entity");
const account_repository_adapter_1 = require("./repositories/account.repository.adapter");
const transfer_repository_adapter_1 = require("./repositories/transfer.repository.adapter");
const account_repository_interface_1 = require("../../../../../core/ports/out/account.repository.interface");
const transfer_repository_interface_1 = require("../../../../../core/ports/out/transfer.repository.interface");
let DatabaseModule = class DatabaseModule {
};
exports.DatabaseModule = DatabaseModule;
exports.DatabaseModule = DatabaseModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forRoot({
                type: 'postgres',
                host: process.env.DB_HOST || 'localhost',
                port: parseInt(process.env.DB_PORT ?? '5432', 10),
                username: process.env.DB_USERNAME || 'postgres',
                password: process.env.DB_PASSWORD || 'postgres',
                database: process.env.DB_NAME || 'internet_banking',
                entities: [account_orm_entity_1.AccountOrmEntity, transfer_orm_entity_1.TransferOrmEntity],
                synchronize: process.env.NODE_ENV !== 'production',
                logging: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
                ssl: process.env.DB_SSL === 'true'
                    ? { rejectUnauthorized: false }
                    : false,
            }),
            typeorm_1.TypeOrmModule.forFeature([account_orm_entity_1.AccountOrmEntity, transfer_orm_entity_1.TransferOrmEntity]),
        ],
        providers: [
            {
                provide: account_repository_interface_1.AccountRepository,
                useClass: account_repository_adapter_1.AccountRepositoryAdapter,
            },
            {
                provide: transfer_repository_interface_1.TransferRepository,
                useClass: transfer_repository_adapter_1.TransferRepositoryAdapter,
            },
            account_repository_adapter_1.AccountRepositoryAdapter,
            transfer_repository_adapter_1.TransferRepositoryAdapter,
        ],
        exports: [account_repository_interface_1.AccountRepository, transfer_repository_interface_1.TransferRepository],
    })
], DatabaseModule);
//# sourceMappingURL=database.module.js.map
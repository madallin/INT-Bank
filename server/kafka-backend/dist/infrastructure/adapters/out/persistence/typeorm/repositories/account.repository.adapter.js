"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var AccountRepositoryAdapter_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AccountRepositoryAdapter = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const account_orm_entity_1 = require("../entities/account.orm-entity");
let AccountRepositoryAdapter = AccountRepositoryAdapter_1 = class AccountRepositoryAdapter {
    constructor(repo) {
        this.repo = repo;
        this.logger = new common_1.Logger(AccountRepositoryAdapter_1.name);
    }
    async findByIban(iban) {
        const entity = await this.repo.findOne({ where: { IBAN: iban } });
        return entity ? this.toDomain(entity) : null;
    }
    async findById(id) {
        const entity = await this.repo.findOne({ where: { id } });
        return entity ? this.toDomain(entity) : null;
    }
    async findByIdWithLock(id, entityManager) {
        if (entityManager) {
            const em = entityManager;
            const entity = await em.findOne(account_orm_entity_1.AccountOrmEntity, {
                where: { id },
                lock: { mode: 'pessimistic_write' },
            });
            return entity ? this.toDomain(entity) : null;
        }
        const entity = await this.repo.findOne({
            where: { id },
            lock: { mode: 'pessimistic_write' },
        });
        return entity ? this.toDomain(entity) : null;
    }
    async updateBalance(accountId, newBalance, entityManager) {
        if (entityManager) {
            const em = entityManager;
            await em.update(account_orm_entity_1.AccountOrmEntity, accountId, { sold: newBalance });
        }
        else {
            await this.repo.update(accountId, { sold: newBalance });
        }
        this.logger.debug(`Account ${accountId} balance updated to ${newBalance}`);
    }
    async getBalance(accountId) {
        const entity = await this.repo.findOne({ where: { id: accountId } });
        if (!entity) {
            throw new common_1.NotFoundException(`Account ${accountId} not found`);
        }
        return {
            accountId: entity.id,
            IBAN: entity.IBAN,
            moneda: entity.moneda,
            sold: entity.sold,
        };
    }
    toDomain(entity) {
        return {
            id: entity.id,
            userId: entity.userId,
            IBAN: entity.IBAN,
            moneda: entity.moneda,
            sold: entity.sold,
            createdAt: entity.createdAt,
        };
    }
};
exports.AccountRepositoryAdapter = AccountRepositoryAdapter;
exports.AccountRepositoryAdapter = AccountRepositoryAdapter = AccountRepositoryAdapter_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(account_orm_entity_1.AccountOrmEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], AccountRepositoryAdapter);
//# sourceMappingURL=account.repository.adapter.js.map
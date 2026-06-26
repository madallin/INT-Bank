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
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransferRepositoryAdapter = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const transfer_orm_entity_1 = require("../entities/transfer.orm-entity");
let TransferRepositoryAdapter = class TransferRepositoryAdapter {
    constructor(repo) {
        this.repo = repo;
    }
    async save(transfer) {
        const entity = this.toEntity(transfer);
        const saved = await this.repo.save(entity);
        return this.toDomain(saved);
    }
    async findById(id) {
        const entity = await this.repo.findOne({ where: { id } });
        return entity ? this.toDomain(entity) : null;
    }
    async updateStatus(id, status, completedAt, failureReason) {
        const updateData = {
            status,
        };
        if (completedAt !== undefined) {
            updateData.completedAt = completedAt;
        }
        if (failureReason !== undefined) {
            updateData.failureReason = failureReason;
        }
        await this.repo.update(id, updateData);
    }
    async findByAccountId(accountId) {
        const entities = await this.repo.find({
            where: [
                { fromAccountId: accountId },
                { toAccountId: accountId },
            ],
            order: { initiatedAt: 'DESC' },
            take: 50,
        });
        return entities.map((e) => this.toDomain(e));
    }
    toDomain(entity) {
        return {
            id: entity.id,
            fromAccountId: entity.fromAccountId,
            toAccountId: entity.toAccountId,
            amount: entity.amount,
            currency: entity.currency,
            reason: entity.reason,
            status: entity.status,
            initiatedAt: entity.initiatedAt,
            completedAt: entity.completedAt,
            failureReason: entity.failureReason,
        };
    }
    toEntity(domain) {
        const entity = new transfer_orm_entity_1.TransferOrmEntity();
        entity.id = domain.id;
        entity.fromAccountId = domain.fromAccountId;
        entity.toAccountId = domain.toAccountId;
        entity.amount = domain.amount;
        entity.currency = domain.currency;
        entity.reason = domain.reason;
        entity.status = domain.status;
        entity.initiatedAt = domain.initiatedAt;
        entity.completedAt = domain.completedAt;
        entity.failureReason = domain.failureReason;
        return entity;
    }
};
exports.TransferRepositoryAdapter = TransferRepositoryAdapter;
exports.TransferRepositoryAdapter = TransferRepositoryAdapter = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(transfer_orm_entity_1.TransferOrmEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], TransferRepositoryAdapter);
//# sourceMappingURL=transfer.repository.adapter.js.map
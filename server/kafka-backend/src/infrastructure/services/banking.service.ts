import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AccountOrmEntity } from '../adapters/out/persistence/typeorm/entities/account.orm-entity';
import { CardOrmEntity } from '../adapters/out/persistence/typeorm/entities/card.orm-entity';
import { CryptoService } from './crypto.service';

const BANK_CODE = 'INTB';
const IBAN_ACCOUNT_LENGTH = 16;
const CARD_BIN = '499999';
const CARD_LENGTH = 16;
const DEFAULT_CARD_LIFETIME_YEARS = 3;
const MAX_RETRIES = 7;

function generateRandomDigits(length: number): string
{
    let result = '';
    for(let i = 0; i < length; i++)
    {
        result += Math.floor(Math.random() * 10).toString();
    }
    return result;
}

function computeIBANChecksum(bban: string): string
{
    const numeric = [...(bban + 'RO00')].map((c) =>
        /[A-Z]/.test(c) ? (c.charCodeAt(0) - 55).toString() : c,
    ).join('');
    const mod = BigInt(numeric) % 97n;
    const checksum = 98n - mod;
    return checksum.toString().padStart(2, '0');
}

function generateIBAN(currency: string, countryCode: string): string
{
    const country = countryCode.toUpperCase().slice(0, 2);
    const bban =
        BANK_CODE +
        generateRandomDigits(4) +
        (currency === 'RON' ? 'RON' : generateRandomDigits(3)) +
        generateRandomDigits(IBAN_ACCOUNT_LENGTH - BANK_CODE.length - 4 - (currency === 'RON' ? 3 : 3));
    const checksum = computeIBANChecksum(bban);
    return `${country}${checksum}${bban}`;
}

@Injectable()
export class BankingService
{
    private readonly logger = new Logger(BankingService.name);

    constructor(
        @InjectDataSource()
        private readonly dataSource: DataSource,
        private readonly cryptoService: CryptoService,
    ) {}

    async createAccountAndCard(
        userId: number,
        currency: string,
        countryCode: string,
    ): Promise<{ account: any; card: any }>
    {
        const IBAN = generateIBAN(currency, countryCode);

        return await this.dataSource.transaction(async (entityManager) =>
        {
            const accountRepo = entityManager.getRepository(AccountOrmEntity);
            const cardRepo = entityManager.getRepository(CardOrmEntity);

            const account = accountRepo.create(
            {
                userId,
                IBAN,
                moneda: currency,
                sold: 0,
            });
            const savedAccount = await accountRepo.save(account);
            const accountId = savedAccount.id;

            const cardNumber = CARD_BIN + generateRandomDigits(CARD_LENGTH - CARD_BIN.length);
            const cvv = generateRandomDigits(3);
            const now = new Date();
            const expiry = new Date(now.getFullYear() + DEFAULT_CARD_LIFETIME_YEARS, now.getMonth(), 1);
            const expiryMMYY = `${(expiry.getMonth() + 1).toString().padStart(2, '0')}/${expiry.getFullYear().toString().slice(-2)}`;

            const encryptedCard = this.cryptoService.encryptAESGCM(cardNumber);
            const encryptedCVV = this.cryptoService.encryptAESGCM(cvv);
            const encryptedExpiry = this.cryptoService.encryptAESGCM(expiryMMYY);
            const token = `tok_${generateRandomDigits(16)}`;

            const card = cardRepo.create(
            {
                userId,
                numarCard: encryptedCard,
                cvv: encryptedCVV,
                dataExpirare: encryptedExpiry,
                detinator: '',
                token,
                accountId,
            });
            const savedCard = await cardRepo.save(card);

            this.logger.log(
                { userId, accountId, IBAN, currency },
                'Account and card created',
            );

            return {
                account:
                {
                    id: accountId,
                    IBAN: savedAccount.IBAN,
                    moneda: savedAccount.moneda,
                    sold: savedAccount.sold,
                },
                card:
                {
                    id: savedCard.id,
                    token,
                    last4: cardNumber.slice(-4),
                    expiryMMYY,
                    accountId,
                },
            };
        });
    }

    async createAccountAndCardWithRetry(
        userId: number,
        currency: string,
        countryCode: string,
        retries: number = MAX_RETRIES,
    ): Promise<{ account: any; card: any }>
    {
        for(let attempt = 1; attempt <= retries; attempt++)
        {
            try
            {
                return await this.createAccountAndCard(userId, currency, countryCode);
            }
            catch (err: any)
            {
                const isUniqueViolation = err.code === '23505';
                if(isUniqueViolation && attempt < retries)
                {
                    this.logger.warn({ attempt }, 'IBAN collision, retrying...');
                    continue;
                }
                this.logger.error(err, 'createAccountAndCard failed');
                throw err;
            }
        }
        throw new Error('Failed to generate unique IBAN after multiple attempts');
    }
}

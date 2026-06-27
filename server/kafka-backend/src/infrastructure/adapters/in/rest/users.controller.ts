import { Controller, Get, Post, Put, Param, Body, UseGuards, Logger } from '@nestjs/common';
import bcrypt from 'bcrypt';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityManager } from 'typeorm';
import { AccountOrmEntity } from '../../out/persistence/typeorm/entities/account.orm-entity';
import { UserOrmEntity } from '../../out/persistence/typeorm/entities/user.orm-entity';
import { UserTokenGuard } from '../../../common/guards/user-token.guard';
import { BankingService } from '../../../services/banking.service';
import { CryptoService } from '../../../services/crypto.service';
import { CurrencyService } from '../../../services/currency.service';

function isValidIBAN(iban: string): boolean
{
    return /^[A-Z]{2}[0-9A-Z]{14,30}$/.test(iban);
}

@Controller('users')
@UseGuards(UserTokenGuard)
export class UsersController
{
    private readonly logger = new Logger(UsersController.name);

    constructor(
        @InjectDataSource() private readonly dataSource: DataSource,
        private readonly bankingService: BankingService,
        private readonly cryptoService: CryptoService,
        private readonly currencyService: CurrencyService,
    ) {}

    @Put(':userId/accept-tos')
    async acceptTos(@Param('userId') userId: string)
    {
        try
        {
            const r = this.dataSource.getRepository(UserOrmEntity);
            const result = await r.update(userId, { termeniAcceptati: true });
            if(result.affected === 0) return { statusCode: 404, error: 'Utilizatorul nu a fost gasit' };
            const updated = await r.findOne({ where: { id: Number(userId) } });
            return { success: true, user: updated };
        }
        catch (err) { this.logger.error(err, 'accept-tos'); return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' }; }
    }

    @Get(':userId/has-tos')
    async hasTos(@Param('userId') userId: string)
    {
        try
        {
            const r = this.dataSource.getRepository(UserOrmEntity);
            const u = await r.findOne({ where: { id: Number(userId) }, select: { termeniAcceptati: true } });
            if(!u) return { statusCode: 404, error: 'Utilizatorul nu a fost gasit' };
            return { termeniAcceptati: u.termeniAcceptati };
        }
        catch (err) { this.logger.error(err, 'has-tos'); return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' }; }
    }

    @Post(':userId/verify-pin')
    async verifyPin(@Param('userId') userId: string, @Body() body: { pin?: string })
    {
        try
        {
            const r = this.dataSource.getRepository(UserOrmEntity);
            const u = await r.findOne({ where: { id: Number(userId) }, select: { id: true, pinCont: true } });
            if(!u || !u.pinCont) return { statusCode: 400, success: false, error: 'PIN invalid' };
            const match = await bcrypt.compare(body.pin || '', u.pinCont);
            return { success: match };
        }
        catch (err) { this.logger.error(err, 'verify-pin'); return { statusCode: 500, success: false, error: 'Eroare la server' }; }
    }

    @Get(':userId/has-pin')
    async hasPin(@Param('userId') userId: string)
    {
        try
        {
            const r = this.dataSource.getRepository(UserOrmEntity);
            const u = await r.findOne({ where: { id: Number(userId) }, select: { pinCont: true } });
            if(!u) return { statusCode: 404, error: 'Utilizatorul nu a fost gasit' };
            return { hasPin: u.pinCont !== null && u.pinCont.length > 0 };
        }
        catch (err) { this.logger.error(err, 'has-pin'); return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' }; }
    }

    @Post(':userId/set-pin')
    async setPin(@Param('userId') userId: string, @Body() body: { pin?: string })
    {
        const { pin } = body;
        if(!pin || pin.length < 4 || pin.length > 6)
            return { statusCode: 400, error: 'PIN-ul trebuie sa aiba intre 4 si 6 caractere' };
        try
        {
            const r = this.dataSource.getRepository(UserOrmEntity);
            const hash = await bcrypt.hash(pin, 12);
            const result = await r.update(userId, { pinCont: hash });
            if(result.affected === 0) return { statusCode: 404, error: 'Utilizatorul nu a fost gasit' };
            return { success: true };
        }
        catch (err) { this.logger.error(err, 'set-pin'); return { statusCode: 500, error: 'Eroare la server' }; }
    }

    @Get(':userId/accounts')
    async getAccounts(@Param('userId') userId: string)
    {
        try
        {
            const r = this.dataSource.getRepository(AccountOrmEntity);
            const accounts = await r.find({ where: { userId: Number(userId) }, order: { createdAt: 'ASC' } });
            if(accounts.length === 0) return { statusCode: 404, error: 'Nu s-au gasit conturi.' };
            return { accounts: accounts.map((a) => ({ id: a.id, iban: a.IBAN, moneda: a.moneda, sold: Number(a.sold).toFixed(2), last4: null })) };
        }
        catch (err) { this.logger.error(err, 'get-accounts'); return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' }; }
    }


    @Get(':userId/accounts/:accountId/masked-card')
    async getMaskedCard(@Param('userId') userId: string, @Param('accountId') accountId: string)
    {
        try
        {
            const rows = await this.dataSource.query(
                'SELECT id, numarcard, cvv, dataexpirare, token FROM carduri WHERE accountid=$1 AND userid=$2 LIMIT 1',
                [Number(accountId), Number(userId)],
            );
            if(rows.length === 0) return { statusCode: 404, error: 'Card negasit.' };
            return {
                card: {
                    id: rows[0].id,
                    last4: this.cryptoService.safeExtractLast4(rows[0].numarcard) || '****',
                    expiryDate: this.cryptoService.decryptAESGCM(rows[0].dataexpirare) || '**/**',
                    token: rows[0].token,
                },
            };
        }
        catch (err) { this.logger.error(err, 'masked-card'); return { statusCode: 500, error: 'Eroare la comunicarea cu serverul' }; }
    }

    @Post(':userId/accounts')
    async createAccount(@Param('userId') userId: string, @Body() body: { currency?: string; countryCode?: string })
    {
        try
        {
            const result = await this.bankingService.createAccountAndCard(Number(userId), (body.currency||'RON').toUpperCase(), (body.countryCode||'RO').toUpperCase());
            return { success: true, ...result };
        }
        catch (err: any)
        {
            this.logger.error(err, 'create-account');
            if(err.code === '23505') return { statusCode: 409, error: 'IBAN duplicat.' };
            return { statusCode: 500, error: 'Eroare la crearea contului' };
        }
    }

    @Post(':userId/transfer')
    async transfer(@Param('userId') userId: string, @Body() body: { fromIban?: string; toIban?: string; amount?: number; reason?: string })
    {
        const { fromIban, toIban, amount, reason } = body;
        const amt = Math.round(parseFloat(String(amount||0))*100)/100;
        if(!fromIban||!toIban||!amount) return { statusCode:400, error:'fromIban, toIban si amount obligatorii' };
        if(!isValidIBAN(fromIban)||!isValidIBAN(toIban)) return { statusCode:400, error:'IBAN invalid' };
        if(isNaN(amt)||amt<=0) return { statusCode:400, error:'Suma pozitiva obligatorie' };
        if(fromIban===toIban) return { statusCode:400, error:'Nu poti transfera in acelasi cont' };
        try
        {
            const result = await this.dataSource.transaction(async (em: EntityManager) =>
            {
                const s = await em.findOne(AccountOrmEntity,{where:{IBAN:fromIban},lock:{mode:'pessimistic_write'}});
                if(!s) throw new Error('Contul sursa nu a fost gasit');
                if(s.userId!==Number(userId)) throw new Error('Contul sursa nu iti apartine');
                const r = await em.findOne(AccountOrmEntity,{where:{IBAN:toIban},lock:{mode:'pessimistic_write'}});
                if(!r) throw new Error('Contul destinatie nu a fost gasit');
                if(Number(s.sold)<amt) throw new Error('Fonduri insuficiente');
                const ca = s.moneda===r.moneda?amt:await this.currencyService.convertCurrency(amt,s.moneda,r.moneda);
                await em.update(AccountOrmEntity,s.id,{sold:Number(s.sold)-amt});
                await em.update(AccountOrmEntity,r.id,{sold:Number(r.sold)+ca});
                const [row]=await em.query('INSERT INTO transferuri(expeditor,receptor,suma,moneda,motiv) VALUES($1,$2,$3,$4,$5) RETURNING id,"dataTransfer"',[s.id,r.id,amt,s.moneda,reason||null]);
                return {id:row.id,dataTransfer:row.dataTransfer,fromAccountId:s.id,toAccountId:r.id,amount:amt,currency:s.moneda,amountReceived:ca,currencyReceived:r.moneda,reason:reason||null};
            });
            return {success:true,transfer:result};
        }
        catch(err:any)
        {
            if(['Fonduri insuficiente','Contul sursa nu a fost gasit','Contul destinatie nu a fost gasit','Contul sursa nu iti apartine'].includes(err.message))
                return {statusCode:400,error:err.message};
            this.logger.error(err,'transfer-error');
            return {statusCode:500,error:'Eroare la procesare transfer'};
        }
    }

    @Get(':userId/accounts/:accountId/transactions')
    async getTransactions(@Param('userId') userId: string, @Param('accountId') accountId: string)
    {
        try
        {
            const rows = await this.dataSource.query(
                "SELECT t.id,t.expeditor,t.receptor,t.suma,t.moneda,t.dataTransfer,t.motiv, CASE WHEN t.expeditor=$2 THEN 'sent' ELSE 'received' END AS type, CASE WHEN t.expeditor=$2 THEN (SELECT iban FROM conturiBancare WHERE id=t.receptor) ELSE (SELECT iban FROM conturiBancare WHERE id=t.expeditor) END AS beneficiary FROM transferuri t WHERE t.expeditor=$2 OR t.receptor=$2 ORDER BY t.dataTransfer DESC LIMIT 50",
                [userId, accountId],
            );
            if(rows.length===0) return {statusCode:404,error:'Nu exista tranzactii'};
            return {transactions:rows};
        }
        catch(err) { this.logger.error(err,'get-transactions'); return {statusCode:500,error:'Eroare la preluarea tranzactiilor'}; }
    }
}

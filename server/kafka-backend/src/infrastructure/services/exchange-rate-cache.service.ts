import { Injectable, Logger } from '@nestjs/common';
import { redis } from '../../config/redis';
import { CurrencyService } from './currency.service';

const CACHE_PREFIX = 'exchange_rate:';
const DEFAULT_TTL_SECONDS = 3600;

@Injectable()
export class ExchangeRateCacheService
{
    private readonly logger = new Logger(ExchangeRateCacheService.name);
    private readonly refreshTimers = new Map<string, NodeJS.Timeout>();

    constructor(
        private readonly currencyService: CurrencyService,
    ) {}

    async getRate(fromCurrency: string, toCurrency: string): Promise<number>
    {
        // Stale-while-revalidate: serve cached rate and refresh in background
        // before TTL expiry to avoid API latency on the next request
        const cacheKey = this.buildKey(fromCurrency, toCurrency);

        try
        {
            const cached = await redis.get(cacheKey);
            const ttl = await redis.ttl(cacheKey);

            if(cached !== null)
            {
                const rate = parseFloat(cached);

                if(ttl > 0 && ttl < 600)
                {
                    this.refreshInBackground(fromCurrency, toCurrency);
                }

                return rate;
            }
        }
        catch(err)
        {
            this.logger.warn(`Redis read failed for ${cacheKey}, falling back to API`, err);
        }

        const rate = await this.currencyService.convertCurrency(1, fromCurrency, toCurrency);
        await this.setCache(fromCurrency, toCurrency, rate);

        return rate;
    }

    async convertAmount(
        amount: number,
        fromCurrency: string,
        toCurrency: string,
    ): Promise<number>
    {
        if(fromCurrency === toCurrency)
        {
            return amount;
        }

        const rate = await this.getRate(fromCurrency, toCurrency);
        return Math.round(amount * rate * 100) / 100;
    }

    async warmCache(pairs: Array<{ from: string; to: string }>): Promise<void>
    {
        const results = await Promise.allSettled(
            pairs.map(async ({ from, to }) =>
            {
                await this.getRate(from, to);
            }),
        );

        const succeeded = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;

        this.logger.log(
            `Cache warm complete: ${succeeded} succeeded, ${failed} failed`,
        );
    }

    // Pre-warm popular pairs every 50 minutes to minimize cache-miss penalties
    scheduleRefresh(
        pairs: Array<{ from: string; to: string }>,
        intervalMs: number = 3000000,
    ): void
    {
        const timer = setInterval(async () =>
        {
            await this.warmCache(pairs);
        }, intervalMs);

        timer.unref();

        const key = 'scheduled_refresh';
        const existing = this.refreshTimers.get(key);

        if(existing)
        {
            clearInterval(existing);
        }

        this.refreshTimers.set(key, timer);
    }

    onModuleDestroy(): void
    {
        this.refreshTimers.forEach((timer) => clearInterval(timer));
        this.refreshTimers.clear();
    }

    private buildKey(from: string, to: string): string
    {
        return `${CACHE_PREFIX}${from.toUpperCase()}:${to.toUpperCase()}`;
    }

    private async setCache(from: string, to: string, rate: number): Promise<void>
    {
        const key = this.buildKey(from, to);

        try
        {
            await redis.setex(key, DEFAULT_TTL_SECONDS, rate.toString());

            // Cache the inverse rate for zero-latency reverse lookups
            const inverseKey = this.buildKey(to, from);
            const inverseRate = 1 / rate;
            await redis.setex(inverseKey, DEFAULT_TTL_SECONDS, inverseRate.toFixed(6));
        }
        catch(err)
        {
            this.logger.error(`Failed to cache exchange rate for ${key}`, err);
        }
    }

    private async refreshInBackground(from: string, to: string): Promise<void>
    {
        const key = `bg_refresh:${from}:${to}`;

        if(this.refreshTimers.has(key))
        {
            return;
        }

        const timer = setTimeout(async () =>
        {
            try
            {
                this.logger.debug(`Background refresh: ${from}->${to}`);
                await this.getRate(from, to);
            }
            finally
            {
                this.refreshTimers.delete(key);
            }
        }, 100);

        timer.unref();
        this.refreshTimers.set(key, timer);
    }
}
import
{
    Controller,
    Get,
    Post,
    Param,
    Query,
    Body,
    Logger,
} from '@nestjs/common';
import axios from 'axios';
import { redis } from '../../../../config/redis';

const FRANKFURTER_API = 'https://api.frankfurter.dev/v2';
const COMMISSION_PERCENT = 1.5;
const CACHE_TTL_SECONDS = 3600;
const CACHE_KEY = 'banking:rates';

@Controller('currency')
export class CurrencyController
{
    private readonly logger = new Logger(CurrencyController.name);

    @Get('api/v1/exchange-rates')
    async getExchangeRates()
    {
        try
        {
            const cached = await redis.get(CACHE_KEY);
            if(cached)
            {
                return JSON.parse(cached);
            }

            const url = `${FRANKFURTER_API}/rates?base=RON&quotes=EUR,USD,GBP`;
            const response = await axios.get(url, { timeout: 10000 });
            const data = response.data;

            if(!Array.isArray(data) || data.length === 0)
            {
                return { statusCode: 502, error: 'Invalid response from Frankfurter API' };
            }

            const rates: Record<string, number> = {};
            for(const entry of data)
            {
                rates[entry.quote] = entry.rate;
            }

            const payload = {
                base: 'RON',
                date: data[0].date,
                rates,
                commissionPercent: COMMISSION_PERCENT,
                last_cached: new Date().toISOString(),
            };

            await redis.setex(CACHE_KEY, CACHE_TTL_SECONDS, JSON.stringify(payload));
            return payload;
        }
        catch (err: any)
        {
            this.logger.error(err, 'Error fetching exchange rates');
            return { statusCode: 502, error: 'Failed to fetch exchange rates' };
        }
    }

    @Post('rate')
    async getRate(@Body() body: { base?: string; quote?: string; amount?: number })
    {
        try
        {
            const { base, quote, amount } = body;
            if(!base || !quote)
            {
                return { statusCode: 400, error: 'base and quote are required' };
            }

            const baseCode = base.toUpperCase();
            const quoteCode = quote.toUpperCase();
            const url = `${FRANKFURTER_API}/rate/${baseCode}/${quoteCode}`;
            const response = await axios.get(url, { timeout: 8000 });
            const data = response.data;

            if(!data || typeof data.rate !== 'number')
            {
                return { statusCode: 502, error: 'Invalid response from exchange rate API' };
            }

            const originalRate = data.rate;
            const rateWithCommission = originalRate * (1 - COMMISSION_PERCENT / 100);
            const parsedAmount = parseFloat(String(amount)) || 1;
            const commissionAmount = parseFloat(
                (parsedAmount * originalRate * (COMMISSION_PERCENT / 100)).toFixed(2),
            );
            const result = parseFloat((parsedAmount * rateWithCommission).toFixed(2));

            return {
                success: true,
                base: baseCode,
                quote: quoteCode,
                originalRate,
                rate: parseFloat(rateWithCommission.toFixed(6)),
                commissionPercent: COMMISSION_PERCENT,
                commissionAmount,
                amount: parsedAmount,
                result,
            };
        }
        catch (err: any)
        {
            this.logger.error(err, 'Error fetching exchange rate');
            if(err.response?.status === 404)
            {
                return { statusCode: 404, error: 'Currency pair not found or not supported' };
            }
            return { statusCode: 502, error: 'Failed to fetch exchange rate' };
        }
    }

    @Get('rate/:base/:quote')
    async getRateByParams(@Param('base') base: string, @Param('quote') quote: string)
    {
        try
        {
            const url = `${FRANKFURTER_API}/rate/${base.toUpperCase()}/${quote.toUpperCase()}`;
            const response = await axios.get(url, { timeout: 8000 });
            return response.data;
        }
        catch (err)
        {
            return { statusCode: 502, error: 'Failed to fetch exchange rate' };
        }
    }

    @Get(':code')
    async getCurrencyByCode(@Param('code') code: string)
    {
        const base = code?.toLowerCase();
        if(!base || base.length !== 3)
        {
            return { statusCode: 400, error: 'Cod valutar invalid (ex: eur, usd, ron)' };
        }

        const primaryUrl = `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${base}.json`;
        const fallbackUrl = `https://latest.currency-api.pages.dev/v1/currencies/${base}.json`;

        try
        {
            const response = await axios.get(primaryUrl, { timeout: 5000 });
            return { success: true, source: 'jsdelivr', data: response.data };
        }
        catch (err1)
        {
            this.logger.warn('Primary API failed, trying fallback...');
            try
            {
                const fallbackResponse = await axios.get(fallbackUrl, { timeout: 5000 });
                return { success: true, source: 'cloudflare', data: fallbackResponse.data };
            }
            catch (err2)
            {
                this.logger.error(err2, 'Eroare la preluarea cursurilor valutare');
                return {
                    statusCode: 500,
                    error: 'Nu s-au putut prelua datele valutare din niciun server.',
                };
            }
        }
    }
}

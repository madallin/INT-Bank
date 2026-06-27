import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

const FRANKFURTER_API = 'https://api.frankfurter.dev/v2/latest';

@Injectable()
export class CurrencyService
{
    private readonly logger = new Logger(CurrencyService.name);

    async convertCurrency(
        amount: number,
        fromCurrency: string,
        toCurrency: string,
    ): Promise<number>
    {
        if(fromCurrency === toCurrency) return amount;

        try
        {
            const url = `${FRANKFURTER_API}?base=${fromCurrency}&symbols=${toCurrency}`;
            const response = await axios.get(url, { timeout: 8000 });
            const rate = response.data?.rates?.[toCurrency];
            if(!rate)
            {
                throw new Error(`No rate found for ${fromCurrency} -> ${toCurrency}`);
            }
            return Math.round(amount * rate);
        }
        catch (err: any)
        {
            this.logger.error(err, 'Error converting currency');
            throw err;
        }
    }
}

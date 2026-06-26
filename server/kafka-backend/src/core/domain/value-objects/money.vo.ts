export class Money
{
  private constructor(
    private readonly _amount: number,
    private readonly _currency: string,
  )
  {
    if(!Number.isFinite(_amount) || _amount < 0)
    {
      throw new Error('Money amount must be a finite non-negative number');
    }
    if(_currency.length !== 3 || _currency !== _currency.toUpperCase())
    {
      throw new Error('Currency must be a 3-letter ISO code (e.g. RON, EUR)');
    }
  }

  static of(amount: number, currency: string = 'RON'): Money
  {
    return new Money(Math.round(amount * 100) / 100, currency.toUpperCase());
  }

  static zero(currency: string = 'RON'): Money
  {
    return new Money(0, currency.toUpperCase());
  }

  get amount(): number
  {
    return this._amount;
  }

  get currency(): string
  {
    return this._currency;
  }

  add(other: Money): Money
  {
    if(this._currency !== other._currency)
    {
      throw new Error(`Currency mismatch: ${this._currency} vs ${other._currency}`);
    }
    return Money.of(this._amount + other._amount, this._currency);
  }

  subtract(other: Money): Money
  {
    if(this._currency !== other._currency)
    {
      throw new Error(`Currency mismatch: ${this._currency} vs ${other._currency}`);
    }
    const result = this._amount - other._amount;
    if(result < 0)
    {
      throw new Error('Insufficient funds');
    }
    return Money.of(result, this._currency);
  }

  equals(other: Money): boolean
  {
    return this._amount === other._amount && this._currency === other._currency;
  }

  toString(): string
  {
    return `${this._amount.toFixed(2)} ${this._currency}`;
  }

  toJSON(): { amount: number; currency: string }
  {
    return { amount: this._amount, currency: this._currency };
  }
}

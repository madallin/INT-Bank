import { Money } from '../value-objects/money.vo';
import { Iban } from '../value-objects/iban.vo';

export class Account
{
  private constructor(
    private readonly _id: string,
    private readonly _userId: number,
    private readonly _iban: Iban,
    private _balance: Money,
    private readonly _currency: string,
    private readonly _createdAt: Date,
    private _updatedAt: Date,
  ) {}

  static create(
    id: string,
    userId: number,
    iban: Iban,
    currency: string = 'RON',
  ): Account
  {
    return new Account(
      id,
      userId,
      iban,
      Money.zero(currency),
      currency,
      new Date(),
      new Date(),
    );
  }

  static restore(
    id: string,
    userId: number,
    iban: Iban,
    balance: Money,
    currency: string,
    createdAt: Date,
    updatedAt: Date,
  ): Account
  {
    return new Account(id, userId, iban, balance, currency, createdAt, updatedAt);
  }

  get id(): string
  {
    return this._id;
  }

  get userId(): number
  {
    return this._userId;
  }

  get iban(): Iban
  {
    return this._iban;
  }

  get balance(): Money
  {
    return this._balance;
  }

  get currency(): string
  {
    return this._currency;
  }

  get createdAt(): Date
  {
    return this._createdAt;
  }

  get updatedAt(): Date
  {
    return this._updatedAt;
  }

  debit(amount: Money): void
  {
    if(amount.currency !== this._currency)
    {
      throw new Error(
        `Currency mismatch: account=${this._currency}, debit=${amount.currency}`,
      );
    }
    this._balance = this._balance.subtract(amount);
    this._updatedAt = new Date();
  }

  credit(amount: Money): void
  {
    if(amount.currency !== this._currency)
    {
      throw new Error(
        `Currency mismatch: account=${this._currency}, credit=${amount.currency}`,
      );
    }
    this._balance = this._balance.add(amount);
    this._updatedAt = new Date();
  }

  hasSufficientFunds(amount: Money): boolean
  {
    return this._balance.amount >= amount.amount;
  }

  toJSON()
  {
    return {
      id: this._id,
      userId: this._userId,
      iban: this._iban.toString(),
      balance: this._balance.toJSON(),
      currency: this._currency,
      createdAt: this._createdAt.toISOString(),
      updatedAt: this._updatedAt.toISOString(),
    };
  }
}

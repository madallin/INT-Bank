export class Iban
{
  private static readonly IBAN_REGEX = /^[A-Z]{2}\d{2}[A-Z0-9]{4,30}$/;
  private readonly _value: string;
  private readonly _countryCode: string;

  private constructor(value: string)
  {
    const normalized = value.replace(/\s+/g, '').toUpperCase();

    if(!Iban.IBAN_REGEX.test(normalized))
    {
      throw new Error(`Invalid IBAN format: ${value}`);
    }

    this._value = normalized;
    this._countryCode = normalized.slice(0, 2);
  }

  static of(value: string): Iban
  {
    return new Iban(value);
  }

  get value(): string
  {
    return this._value;
  }

  get countryCode(): string
  {
    return this._countryCode;
  }

  get formatted(): string
  {
    return this._value.replace(/(.{4})/g, '$1 ').trim();
  }

  get masked(): string
  {
    return `${this._value.slice(0, 4)} **** ${this._value.slice(-4)}`;
  }

  equals(other: Iban): boolean
  {
    return this._value === other._value;
  }

  toString(): string
  {
    return this._value;
  }
}

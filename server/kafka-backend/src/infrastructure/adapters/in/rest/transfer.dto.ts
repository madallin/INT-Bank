import {
  IsString,
  IsNumber,
  IsOptional,
  MinLength,
  MaxLength,
  Min,
  Matches,
} from 'class-validator';

export class CreateTransferDto
{
  @IsString()
  @MinLength(16)
  @MaxLength(34)
  @Matches(/^[A-Z]{2}\d{2}[A-Z0-9]+$/, {
    message: 'fromIban must be a valid IBAN',
  })
  readonly fromIban!: string;

  @IsString()
  @MinLength(16)
  @MaxLength(34)
  @Matches(/^[A-Z]{2}\d{2}[A-Z0-9]+$/, {
    message: 'toIban must be a valid IBAN',
  })
  readonly toIban!: string;

  @IsString()
  readonly fromAccountId!: string;

  @IsString()
  readonly toAccountId!: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01, { message: 'Amount must be greater than 0' })
  readonly amount!: number;

  @IsString()
  @Matches(/^[A-Z]{3}$/, {
    message: 'Currency must be a 3-letter ISO code (e.g., RON, EUR)',
  })
  readonly currency!: string;

  @IsOptional()
  @IsString()
  @MaxLength(140)
  readonly description?: string;
}

export class TransferStatusResponse
{
  readonly trackingId!: string;
  readonly status!: string;
  readonly failureReason!: string | null;
  readonly transfer!: Record<string, unknown> | null;

  constructor(partial: Partial<TransferStatusResponse>)
  {
    Object.assign(this, partial);
  }
}

export class InitiateTransferResponse
{
  readonly trackingId!: string;
  readonly status!: string;
  readonly message!: string;

  constructor(partial: Partial<InitiateTransferResponse>)
  {
    Object.assign(this, partial);
  }
}

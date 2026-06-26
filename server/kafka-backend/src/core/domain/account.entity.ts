export interface Account
{
  id: number;
  userId: number;
  IBAN: string;
  moneda: string;
  sold: number;
  createdAt?: Date;
}

export interface AccountBalance
{
  accountId: number;
  IBAN: string;
  moneda: string;
  sold: number;
}

export class TransferFailedEvent
{
  constructor(
    public readonly trackingId: string,
    public readonly fromAccountId: string,
    public readonly toAccountId: string,
    public readonly fromIban: string,
    public readonly toIban: string,
    public readonly amount: number,
    public readonly currency: string,
    public readonly failureReason: string,
    public readonly failedAt: Date = new Date(),
  ) {}

  static eventName = 'transfer.failed';
}

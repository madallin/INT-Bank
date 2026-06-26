export class TransferCompletedEvent
{
  constructor(
    public readonly trackingId: string,
    public readonly fromAccountId: string,
    public readonly toAccountId: string,
    public readonly fromIban: string,
    public readonly toIban: string,
    public readonly amount: number,
    public readonly currency: string,
    public readonly completedAt: Date = new Date(),
  ) {}

  static eventName = 'transfer.completed';
}

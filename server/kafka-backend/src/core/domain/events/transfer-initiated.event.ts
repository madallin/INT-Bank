export class TransferInitiatedEvent
{
  constructor(
    public readonly trackingId: string,
    public readonly fromAccountId: string,
    public readonly toAccountId: string,
    public readonly fromIban: string,
    public readonly toIban: string,
    public readonly amount: number,
    public readonly currency: string,
    public readonly description: string,
    public readonly timestamp: Date = new Date(),
  ) {}

  static eventName = 'transfer.initiated';
}

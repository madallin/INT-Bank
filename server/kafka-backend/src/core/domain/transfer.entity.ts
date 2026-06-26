export enum TransferStatus
{
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

export interface Transfer
{
  id: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  reason: string;
  status: TransferStatus;
  initiatedAt: Date;
  completedAt?: Date;
  failureReason?: string;
}

export interface TransferInitiatedEvent
{
  eventType: 'transfer.initiated';
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  reason: string;
  initiatedAt: string;
}

export interface TransferCompletedEvent
{
  eventType: 'transfer.completed';
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  completedAt: string;
}

export interface TransferFailedEvent
{
  eventType: 'transfer.failed';
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  failureReason: string;
  failedAt: string;
}

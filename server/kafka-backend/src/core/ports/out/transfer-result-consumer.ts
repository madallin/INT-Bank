import { TransferCompletedEvent } from '../../domain/events/transfer-completed.event';
import { TransferFailedEvent } from '../../domain/events/transfer-failed.event';

export type TransferResult =
  | { kind: 'completed'; event: TransferCompletedEvent }
  | { kind: 'failed'; event: TransferFailedEvent };

export abstract class TransferResultConsumer
{
  abstract onTransferCompleted(event: TransferCompletedEvent): Promise<void>;
  abstract onTransferFailed(event: TransferFailedEvent): Promise<void>;
}

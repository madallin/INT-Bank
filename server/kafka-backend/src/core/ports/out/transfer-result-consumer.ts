// ============================================================
// Outbound Port: TransferResultConsumer
// Hexagonal Architecture — Core Domain Layer
// This interface defines how transfer processing results
// are consumed from the message broker.
// ============================================================

import { TransferCompletedEvent } from '../../domain/events/transfer-completed.event';
import { TransferFailedEvent } from '../../domain/events/transfer-failed.event';

export type TransferResult =
  | { kind: 'completed'; event: TransferCompletedEvent }
  | { kind: 'failed'; event: TransferFailedEvent };

export abstract class TransferResultConsumer {
  /**
   * Process a completed transfer event.
   */
  abstract onTransferCompleted(event: TransferCompletedEvent): Promise<void>;

  /**
   * Process a failed transfer event.
   */
  abstract onTransferFailed(event: TransferFailedEvent): Promise<void>;
}

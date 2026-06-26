// ============================================================
// Transfer Entity (Domain Layer — Core Domain)
// Hexagonal Architecture — Core Domain
// ============================================================

/**
 * Possible states in the transfer lifecycle.
 */
export enum TransferStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

/**
 * Core domain entity representing a money transfer between two accounts.
 */
export interface Transfer {
  /** Auto-generated UUID or DB ID */
  id: string;

  /** Source account identifier */
  fromAccountId: number;

  /** Destination account identifier */
  toAccountId: number;

  /** Transfer amount in minor units / integer (e.g., cents) */
  amount: number;

  /** Currency of the transfer */
  currency: string;

  /** Human-readable reason / description */
  reason: string;

  /** Current lifecycle status */
  status: TransferStatus;

  /** Timestamp when the transfer was initiated */
  initiatedAt: Date;

  /** Timestamp when processing completed or failed */
  completedAt?: Date;

  /** Human-readable failure reason (set when status = FAILED) */
  failureReason?: string;
}

/**
 * Payload emitted to Kafka when the transfer is initiated.
 */
export interface TransferInitiatedEvent {
  eventType: 'transfer.initiated';
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  reason: string;
  initiatedAt: string;
}

/**
 * Payload emitted to Kafka when the transfer completes successfully.
 */
export interface TransferCompletedEvent {
  eventType: 'transfer.completed';
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  completedAt: string;
}

/**
 * Payload emitted to Kafka when the transfer fails.
 */
export interface TransferFailedEvent {
  eventType: 'transfer.failed';
  transferId: string;
  fromAccountId: number;
  toAccountId: number;
  amount: number;
  currency: string;
  failureReason: string;
  failedAt: string;
}

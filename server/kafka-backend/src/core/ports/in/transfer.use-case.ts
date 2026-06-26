// ============================================================
// Transfer Use Case Port (Inbound Port — Driving Side)
// Hexagonal Architecture — Ports (Core Domain)
// ============================================================

import {
  Transfer,
  TransferInitiatedEvent,
} from '../../domain/transfer.entity';

/**
 * Request DTO for initiating a transfer via REST.
 */
export interface InitiateTransferRequest {
  fromIban: string;
  toIban: string;
  amount: number;
  currency: string;
  reason: string;
  beneficiaryName: string;
  senderName: string;
}

/**
 * Response DTO returned to the HTTP client.
 */
export interface InitiateTransferResponse {
  trackingId: string;
  status: Transfer['status'];
  message: string;
}

/**
 * Primary port (driving) that the application layer implements
 * and the inbound adapter (REST controller) calls.
 */
export abstract class TransferUseCase {
  /**
   * Validates the transfer request and publishes a `transfer.initiated`
   * event to Kafka. Returns immediately with a tracking ID.
   */
  abstract initiate(
    request: InitiateTransferRequest,
  ): Promise<InitiateTransferResponse>;

  /**
   * Returns the event payload that was published.
   * Useful for idempotency checks or debugging.
   */
  abstract getLastPublishedEvent(): TransferInitiatedEvent | null;
}

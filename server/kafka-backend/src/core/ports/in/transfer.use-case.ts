import type {
  Transfer,
  TransferInitiatedEvent,
} from '../../domain/transfer.entity';

export interface InitiateTransferRequest
{
  fromIban: string;
  toIban: string;
  amount: number;
  currency: string;
  reason: string;
  beneficiaryName: string;
  senderName: string;
}

export interface InitiateTransferResponse
{
  trackingId: string;
  status: Transfer['status'];
  message: string;
}

export abstract class TransferUseCase
{
  abstract initiate(
    request: InitiateTransferRequest,
  ): Promise<InitiateTransferResponse>;

  abstract getLastPublishedEvent(): TransferInitiatedEvent | null;
}

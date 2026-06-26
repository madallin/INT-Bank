// ============================================================
// Domain Entity: Transfer
// Hexagonal Architecture — Core Domain Layer
// Pure domain entity with NO framework or ORM dependencies.
// ============================================================

import { Money } from '../value-objects/money.vo';
import { Iban } from '../value-objects/iban.vo';
import { TransferStatus, isValidTransition } from '../value-objects/transfer-status.vo';

export class Transfer {
  private constructor(
    private readonly _id: string,
    private readonly _fromAccountId: string,
    private readonly _toAccountId: string,
    private readonly _fromIban: Iban,
    private readonly _toIban: Iban,
    private readonly _amount: Money,
    private readonly _description: string,
    private _status: TransferStatus,
    private _failureReason: string | null,
    private readonly _createdAt: Date,
    private _updatedAt: Date,
  ) {}

  static create(
    id: string,
    fromAccountId: string,
    toAccountId: string,
    fromIban: Iban,
    toIban: Iban,
    amount: Money,
    description: string = '',
  ): Transfer {
    if (fromIban.equals(toIban)) {
      throw new Error('Cannot transfer to the same account');
    }

    return new Transfer(
      id,
      fromAccountId,
      toAccountId,
      fromIban,
      toIban,
      amount,
      description,
      TransferStatus.PENDING,
      null,
      new Date(),
      new Date(),
    );
  }

  static restore(
    id: string,
    fromAccountId: string,
    toAccountId: string,
    fromIban: Iban,
    toIban: Iban,
    amount: Money,
    description: string,
    status: TransferStatus,
    failureReason: string | null,
    createdAt: Date,
    updatedAt: Date,
  ): Transfer {
    return new Transfer(
      id,
      fromAccountId,
      toAccountId,
      fromIban,
      toIban,
      amount,
      description,
      status,
      failureReason,
      createdAt,
      updatedAt,
    );
  }

  // ---- Getters ----

  get id(): string {
    return this._id;
  }

  get fromAccountId(): string {
    return this._fromAccountId;
  }

  get toAccountId(): string {
    return this._toAccountId;
  }

  get fromIban(): Iban {
    return this._fromIban;
  }

  get toIban(): Iban {
    return this._toIban;
  }

  get amount(): Money {
    return this._amount;
  }

  get description(): string {
    return this._description;
  }

  get status(): TransferStatus {
    return this._status;
  }

  get failureReason(): string | null {
    return this._failureReason;
  }

  get createdAt(): Date {
    return this._createdAt;
  }

  get updatedAt(): Date {
    return this._updatedAt;
  }

  // ---- Behaviour ----

  complete(): void {
    if (!isValidTransition(this._status, TransferStatus.COMPLETED)) {
      throw new Error(
        `Cannot complete transfer in status: ${this._status}`,
      );
    }
    this._status = TransferStatus.COMPLETED;
    this._updatedAt = new Date();
  }

  fail(reason: string): void {
    if (!isValidTransition(this._status, TransferStatus.FAILED)) {
      throw new Error(
        `Cannot fail transfer in status: ${this._status}`,
      );
    }
    this._status = TransferStatus.FAILED;
    this._failureReason = reason;
    this._updatedAt = new Date();
  }

  isTerminal(): boolean {
    return (
      this._status === TransferStatus.COMPLETED ||
      this._status === TransferStatus.FAILED
    );
  }

  toJSON() {
    return {
      id: this._id,
      fromAccountId: this._fromAccountId,
      toAccountId: this._toAccountId,
      fromIban: this._fromIban.toString(),
      toIban: this._toIban.toString(),
      amount: this._amount.toJSON(),
      description: this._description,
      status: this._status,
      failureReason: this._failureReason,
      createdAt: this._createdAt.toISOString(),
      updatedAt: this._updatedAt.toISOString(),
    };
  }
}

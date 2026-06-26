// ============================================================
// Account Entity (Domain Layer — Core Domain)
// Hexagonal Architecture — Core Domain
// ============================================================

/**
 * Represents a bank account in the domain.
 */
export interface Account {
  /** Internal database ID */
  id: number;

  /** User who owns this account */
  userId: number;

  /** IBAN (e.g., RO49INTB1234567890) */
  IBAN: string;

  /** Currency code (RON, EUR, USD, GBP) */
  moneda: string;

  /** Current balance */
  sold: number;

  /** Timestamp when the account was created */
  createdAt?: Date;
}

/**
 * Read-only projection returned after a successful transfer.
 */
export interface AccountBalance {
  accountId: number;
  IBAN: string;
  moneda: string;
  sold: number;
}

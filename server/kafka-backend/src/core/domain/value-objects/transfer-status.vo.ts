// ============================================================
// Domain Value Object: TransferStatus
// Hexagonal Architecture — Core Domain Layer
// Enum-like sealed class for transfer lifecycle states.
// ============================================================

export enum TransferStatus {
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
}

/**
 * Checks if a status transition is valid.
 * Rules:
 *  - PENDING → COMPLETED | FAILED  (allowed)
 *  - COMPLETED/FAILED → anything   (terminal — disallowed)
 */
export function isValidTransition(
  from: TransferStatus,
  to: TransferStatus,
): boolean {
  if (from === TransferStatus.PENDING) {
    return (
      to === TransferStatus.COMPLETED || to === TransferStatus.FAILED
    );
  }
  return false;
}

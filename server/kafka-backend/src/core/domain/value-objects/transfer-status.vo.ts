export enum TransferStatus
{
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
}

// PENDING is the only non-terminal state — transitions to COMPLETED or FAILED only
export function isValidTransition(
  from: TransferStatus,
  to: TransferStatus,
): boolean
{
  if(from === TransferStatus.PENDING)
  {
    return (
      to === TransferStatus.COMPLETED || to === TransferStatus.FAILED
    );
  }
  return false;
}

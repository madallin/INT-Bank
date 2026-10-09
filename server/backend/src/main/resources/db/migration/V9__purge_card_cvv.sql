-- ============================================================================
-- V9: Stop retaining card security codes.
--
-- PCI DSS forbids storing the CVV/CVC after authorization. The application no
-- longer generates or maps the column; this purges every stored value.
-- The empty column is left in place (expand/contract, see V7) and can be
-- dropped by a later contract migration once no running version references it.
-- ============================================================================

SET lock_timeout = '3s';
SET statement_timeout = '30s';

UPDATE cards SET cvv = NULL WHERE cvv IS NOT NULL;

COMMENT ON COLUMN cards.cvv IS 'DEPRECATED (V9): always NULL, never written; drop in a contract migration.';

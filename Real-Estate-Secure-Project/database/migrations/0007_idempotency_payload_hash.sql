ALTER TABLE escrow_transactions
  ADD COLUMN IF NOT EXISTS idempotency_payload_hash CHAR(64);

CREATE INDEX IF NOT EXISTS idx_escrow_idempotency_payload_hash
  ON escrow_transactions (idempotency_payload_hash);

ALTER TABLE exchange_rates
  ADD COLUMN IF NOT EXISTS provider VARCHAR(50),
  ADD COLUMN IF NOT EXISTS fetched_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_exchange_rates_provider
  ON exchange_rates (provider);

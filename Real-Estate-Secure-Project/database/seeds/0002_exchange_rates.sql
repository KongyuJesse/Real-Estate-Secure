INSERT INTO exchange_rates (base_currency, quote_currency, rate, effective_at)
VALUES
  ('XAF', 'USD', 0.0016, TIMESTAMPTZ '2024-01-01T00:00:00Z'),
  ('XAF', 'EUR', 0.0015, TIMESTAMPTZ '2024-01-01T00:00:00Z'),
  ('XAF', 'GBP', 0.0013, TIMESTAMPTZ '2024-01-01T00:00:00Z'),
  ('XAF', 'NGN', 1.20, TIMESTAMPTZ '2024-01-01T00:00:00Z')
ON CONFLICT (base_currency, quote_currency, effective_at)
DO UPDATE SET rate = EXCLUDED.rate;

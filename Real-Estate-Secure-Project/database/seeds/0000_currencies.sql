INSERT INTO currencies (code, name, symbol, is_active)
VALUES
  ('XAF', 'Central African CFA franc', 'FCFA', true),
  ('USD', 'United States Dollar', '$', true),
  ('EUR', 'Euro', '€', true),
  ('GBP', 'British Pound', '£', true),
  ('NGN', 'Nigerian Naira', '₦', true)
ON CONFLICT (code) DO NOTHING;

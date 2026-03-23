ALTER TABLE login_attempts
  ADD COLUMN IF NOT EXISTS device_fingerprint TEXT,
  ADD COLUMN IF NOT EXISTS device_id TEXT,
  ADD COLUMN IF NOT EXISTS is_suspicious BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS risk_score NUMERIC(4,2);

CREATE INDEX IF NOT EXISTS idx_login_attempts_user_created
  ON login_attempts (user_id, created_at);

CREATE INDEX IF NOT EXISTS idx_login_attempts_device
  ON login_attempts (device_fingerprint);

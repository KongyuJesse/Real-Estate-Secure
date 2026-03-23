ALTER TABLE auth_action_tokens
  DROP CONSTRAINT IF EXISTS auth_action_tokens_action_type_check;

ALTER TABLE auth_action_tokens
  ADD CONSTRAINT auth_action_tokens_action_type_check
  CHECK (
    action_type IN (
      'email_verification',
      'password_reset',
      'phone_verification',
      'mfa_login',
      'biometric_login'
    )
  );
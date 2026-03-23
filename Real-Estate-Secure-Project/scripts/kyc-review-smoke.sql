BEGIN;

DO $$
DECLARE
  user_id BIGINT;
  doc_id BIGINT;
  task_id BIGINT;
BEGIN
  INSERT INTO users (
    email,
    phone_number,
    password_hash,
    first_name,
    last_name,
    date_of_birth,
    terms_accepted_at,
    privacy_accepted_at
  )
  VALUES (
    'smoke+' || substring(gen_random_uuid()::text, 1, 8) || '@example.com',
    '+2376' || lpad((floor(random() * 100000000)::int)::text, 8, '0'),
    'smoke-hash',
    'Smoke',
    'Test',
    '1990-01-01',
    now(),
    now()
  )
  RETURNING id INTO user_id;

  INSERT INTO identity_documents (
    user_id,
    document_type,
    document_number,
    issuing_country,
    issue_date,
    expiry_date,
    first_name,
    last_name,
    date_of_birth,
    front_image_path,
    verification_status,
    created_at,
    updated_at
  )
  VALUES (
    user_id,
    'passport',
    'SMOKE-12345',
    'Cameroon',
    '2020-01-01',
    '2030-01-01',
    'Smoke',
    'Test',
    '1990-01-01',
    'kyc/front/smoke.jpg',
    'pending',
    now(),
    now()
  )
  RETURNING id INTO doc_id;

  INSERT INTO kyc_review_tasks (
    document_id,
    status,
    priority,
    sla_due_at,
    reason,
    flags,
    risk_score,
    created_at,
    updated_at
  )
  VALUES (
    doc_id,
    'open',
    'normal',
    now() + interval '24 hours',
    'smoke_test',
    '{"flags":["smoke_test"]}',
    0.2,
    now(),
    now()
  )
  RETURNING id INTO task_id;

  UPDATE kyc_review_tasks
  SET assigned_to = user_id,
      status = 'in_review',
      updated_at = now()
  WHERE id = task_id;

  UPDATE kyc_review_tasks
  SET status = 'resolved',
      updated_at = now()
  WHERE id = task_id;
END $$;

ROLLBACK;

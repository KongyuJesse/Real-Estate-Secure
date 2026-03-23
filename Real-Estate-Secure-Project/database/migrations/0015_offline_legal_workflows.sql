DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'offline_procedure_step_type'
  ) THEN
    CREATE TYPE offline_procedure_step_type AS ENUM (
      'notary_office_step',
      'municipal_certificate_step',
      'tax_registration_step',
      'mindcaf_filing_step',
      'court_case_step',
      'justice_execution_step',
      'commission_visit_step',
      'cadastral_validation_step'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'offline_physical_status'
  ) THEN
    CREATE TYPE offline_physical_status AS ENUM (
      'awaiting_notary_appointment',
      'awaiting_municipal_certificate',
      'awaiting_registration_receipt',
      'awaiting_mindcaf_filing',
      'awaiting_court_hearing',
      'awaiting_final_judgment',
      'awaiting_non_objection',
      'awaiting_commission_visit',
      'in_review',
      'completed',
      'blocked',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'legal_case_workflow_type'
  ) THEN
    CREATE TYPE legal_case_workflow_type AS ENUM (
      'administrative_appeal',
      'administrative_litigation',
      'justice_execution',
      'succession_case',
      'judgment_enforcement',
      'domain_national_allocation',
      'old_title_regularization',
      'foreign_party_authorization'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'legal_case_status'
  ) THEN
    CREATE TYPE legal_case_status AS ENUM (
      'pending_filing',
      'active',
      'awaiting_decision',
      'resolved',
      'closed',
      'blocked'
    );
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    ALTER TYPE property_inventory_type
      ADD VALUE IF NOT EXISTS 'old_title_regularization';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'cadastral_signed_plan';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'site_visit_report';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'partition_record';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'stamped_filing_receipt';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'hearing_notice';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'clerk_issued_document';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'certified_judgment_copy';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'certificate_of_non_appeal';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'ministerial_non_objection';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'site_visit_report';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'partition_record';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'cadastral_signed_plan';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'commission_minutes';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_legal_case_type
      ADD VALUE IF NOT EXISTS 'administrative_appeal_sale';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_legal_case_type
      ADD VALUE IF NOT EXISTS 'administrative_litigation_sale';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_legal_case_type
      ADD VALUE IF NOT EXISTS 'domain_national_allocation_sale';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_legal_case_type
      ADD VALUE IF NOT EXISTS 'old_title_regularization_sale';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;
END $$;

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS old_title_risk BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS court_linked BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ministry_filing_required BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS automation_frozen BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS automation_freeze_reason TEXT,
  ADD COLUMN IF NOT EXISTS assisted_lane_reason TEXT,
  ADD COLUMN IF NOT EXISTS offline_workflow_required BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE property_documents
  ADD COLUMN IF NOT EXISTS original_seen_by BIGINT
    REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS original_seen_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS certified_copy_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS seen_at_location VARCHAR(255);

ALTER TABLE transaction_documents
  ADD COLUMN IF NOT EXISTS original_seen_by BIGINT
    REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS original_seen_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS certified_copy_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS seen_at_location VARCHAR(255),
  ADD COLUMN IF NOT EXISTS issuing_office VARCHAR(255);

CREATE TABLE IF NOT EXISTS transaction_offline_steps (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  property_id BIGINT REFERENCES properties(id) ON DELETE RESTRICT,
  step_type offline_procedure_step_type NOT NULL,
  physical_status offline_physical_status NOT NULL,
  expected_office VARCHAR(255),
  assigned_role VARCHAR(50),
  filing_date DATE,
  scheduled_at TIMESTAMPTZ,
  next_follow_up_date DATE,
  completed_at TIMESTAMPTZ,
  delay_reason TEXT,
  original_required BOOLEAN NOT NULL DEFAULT false,
  oversight_required BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  updated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transaction_legal_cases (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  property_id BIGINT REFERENCES properties(id) ON DELETE RESTRICT,
  case_type legal_case_workflow_type NOT NULL,
  status legal_case_status NOT NULL DEFAULT 'pending_filing',
  freezes_automation BOOLEAN NOT NULL DEFAULT true,
  requires_admin_oversight BOOLEAN NOT NULL DEFAULT false,
  expected_office VARCHAR(255),
  reference_number VARCHAR(255),
  court_name VARCHAR(255),
  filing_date DATE,
  next_follow_up_date DATE,
  final_decision_date DATE,
  delay_reason TEXT,
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  updated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

UPDATE properties
SET risk_lane = 'assisted_only'::property_risk_lane,
    admission_status = 'assisted_only'::property_admission_status,
    admission_profile = admission_profile || jsonb_build_object(
      'risk_lane', 'assisted_only',
      'admission_status', 'assisted_only',
      'notes', jsonb_build_array(
        'Domain national inventory is routed into the assisted legal lane.'
      )
    )
WHERE inventory_type::text = 'domain_national'
  AND risk_lane = 'blocked'::property_risk_lane;

CREATE INDEX IF NOT EXISTS idx_transactions_automation_freeze
  ON transactions (automation_frozen, offline_workflow_required, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_properties_offline_risks
  ON properties (
    inventory_type,
    old_title_risk,
    court_linked,
    ministry_filing_required,
    risk_lane,
    admission_status
  );

CREATE INDEX IF NOT EXISTS idx_transaction_offline_steps_tx
  ON transaction_offline_steps (transaction_id, physical_status, step_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transaction_legal_cases_tx
  ON transaction_legal_cases (transaction_id, status, case_type, created_at DESC);

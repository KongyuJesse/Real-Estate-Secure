DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'property_inventory_type'
  ) THEN
    CREATE TYPE property_inventory_type AS ENUM (
      'titled_private',
      'untitled_customary',
      'domain_national',
      'succession_estate',
      'judgment_enforcement',
      'other'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'property_risk_lane'
  ) THEN
    CREATE TYPE property_risk_lane AS ENUM (
      'government_light',
      'assisted_only',
      'blocked'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'property_admission_status'
  ) THEN
    CREATE TYPE property_admission_status AS ENUM (
      'under_review',
      'eligible',
      'assisted_only',
      'blocked'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'transaction_closing_stage'
  ) THEN
    CREATE TYPE transaction_closing_stage AS ENUM (
      'pre_closing',
      'commercially_closed',
      'notarial_deed_signed',
      'mutation_filed',
      'title_transfer_confirmed'
    );
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'certificate_of_property';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'urbanism_certificate';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'accessibility_certificate';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE property_document_type
      ADD VALUE IF NOT EXISTS 'municipal_certificate';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;
END $$;

DO $$
BEGIN
  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'registration_receipt';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'title_mutation_receipt';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER TYPE transaction_document_type
      ADD VALUE IF NOT EXISTS 'updated_title_evidence';
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;
END $$;

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS inventory_type property_inventory_type,
  ADD COLUMN IF NOT EXISTS risk_lane property_risk_lane
    NOT NULL DEFAULT 'government_light',
  ADD COLUMN IF NOT EXISTS admission_status property_admission_status
    NOT NULL DEFAULT 'under_review',
  ADD COLUMN IF NOT EXISTS admission_profile JSONB
    NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS seller_identity_verified_snapshot BOOLEAN
    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS declared_encumbrance BOOLEAN
    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS declared_dispute BOOLEAN
    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS foreign_party_expected BOOLEAN
    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS municipal_certificate_required BOOLEAN
    NOT NULL DEFAULT false;

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS closing_stage transaction_closing_stage
    NOT NULL DEFAULT 'pre_closing',
  ADD COLUMN IF NOT EXISTS commercially_closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notarial_deed_signed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS mutation_filed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS title_transfer_confirmed_at TIMESTAMPTZ;

UPDATE properties
SET risk_lane = CASE
      WHEN listing_type::text IN ('rent', 'lease') THEN 'government_light'::property_risk_lane
      ELSE 'government_light'::property_risk_lane
    END,
    admission_status = CASE
      WHEN listing_type::text IN ('rent', 'lease') THEN 'eligible'::property_admission_status
      ELSE 'under_review'::property_admission_status
    END,
    admission_profile = CASE
      WHEN listing_type::text IN ('rent', 'lease') THEN
        jsonb_build_object(
          'listing_type', listing_type::text,
          'risk_lane', 'government_light',
          'admission_status', 'eligible',
          'marketplace_eligible', true,
          'notes', jsonb_build_array(
            'Legacy non-sale listing marked eligible during low-risk marketplace migration.'
          )
        )
      ELSE
        jsonb_build_object(
          'listing_type', listing_type::text,
          'risk_lane', 'government_light',
          'admission_status', 'under_review',
          'marketplace_eligible', false,
          'notes', jsonb_build_array(
            'Legacy sale listing requires government-light reassessment before marketplace approval.'
          )
        )
    END
WHERE admission_profile = '{}'::jsonb;

UPDATE transactions
SET closing_stage = CASE
      WHEN transaction_type::text = 'sale' AND transaction_status::text = 'completed'
        THEN 'title_transfer_confirmed'::transaction_closing_stage
      WHEN transaction_type::text = 'sale'
        AND transaction_status::text IN (
          'documents_verified',
          'inspection_period',
          'lawyer_approval'
        )
        THEN 'commercially_closed'::transaction_closing_stage
      ELSE 'pre_closing'::transaction_closing_stage
    END,
    commercially_closed_at = CASE
      WHEN transaction_type::text = 'sale'
        AND transaction_status::text IN (
          'documents_verified',
          'inspection_period',
          'lawyer_approval',
          'completed'
        )
        AND commercially_closed_at IS NULL
        THEN now()
      ELSE commercially_closed_at
    END,
    title_transfer_confirmed_at = CASE
      WHEN transaction_type::text = 'sale'
        AND transaction_status::text = 'completed'
        AND title_transfer_confirmed_at IS NULL
        THEN COALESCE(completion_date, now())
      ELSE title_transfer_confirmed_at
    END;

CREATE INDEX IF NOT EXISTS idx_properties_low_risk_admission
  ON properties (listing_type, risk_lane, admission_status, property_status);

CREATE INDEX IF NOT EXISTS idx_transactions_closing_stage
  ON transactions (transaction_type, closing_stage, transaction_status, created_at DESC);

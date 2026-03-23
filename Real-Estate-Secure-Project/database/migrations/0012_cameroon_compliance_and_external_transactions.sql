DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'transaction_settlement_mode'
  ) THEN
    CREATE TYPE transaction_settlement_mode AS ENUM (
      'platform_escrow',
      'off_platform',
      'hybrid'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'settlement_payment_channel'
  ) THEN
    CREATE TYPE settlement_payment_channel AS ENUM (
      'mobile_money',
      'bank_transfer',
      'cash',
      'cheque',
      'notary',
      'other'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'settlement_declaration_status'
  ) THEN
    CREATE TYPE settlement_declaration_status AS ENUM (
      'pending_review',
      'counterparty_rejected',
      'confirmed',
      'rejected',
      'flagged'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'settlement_confirmation_status'
  ) THEN
    CREATE TYPE settlement_confirmation_status AS ENUM (
      'pending',
      'confirmed',
      'rejected'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'payout_request_status'
  ) THEN
    CREATE TYPE payout_request_status AS ENUM (
      'pending',
      'processing',
      'approved',
      'paid',
      'rejected',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'transaction_legal_review_decision'
  ) THEN
    CREATE TYPE transaction_legal_review_decision AS ENUM (
      'approved',
      'rejected',
      'needs_information'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS cameroon_regions (
  code VARCHAR(20) PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  capital VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cameroon_departments (
  code VARCHAR(40) PRIMARY KEY,
  region_code VARCHAR(20) NOT NULL REFERENCES cameroon_regions(code) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (region_code, name)
);

INSERT INTO cameroon_regions (code, name, capital)
VALUES
  ('adamawa', 'Adamawa', 'Ngaoundere'),
  ('centre', 'Centre', 'Yaounde'),
  ('east', 'East', 'Bertoua'),
  ('far-north', 'Far North', 'Maroua'),
  ('littoral', 'Littoral', 'Douala'),
  ('north', 'North', 'Garoua'),
  ('north-west', 'North-West', 'Bamenda'),
  ('west', 'West', 'Bafoussam'),
  ('south', 'South', 'Ebolowa'),
  ('south-west', 'South-West', 'Buea')
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    capital = EXCLUDED.capital;

INSERT INTO cameroon_departments (code, region_code, name)
VALUES
  ('adamawa-djerem', 'adamawa', 'Djerem'),
  ('adamawa-faro-et-deo', 'adamawa', 'Faro-et-Deo'),
  ('adamawa-mayo-banyo', 'adamawa', 'Mayo-Banyo'),
  ('adamawa-mbere', 'adamawa', 'Mbere'),
  ('adamawa-vina', 'adamawa', 'Vina'),
  ('centre-haute-sanaga', 'centre', 'Haute-Sanaga'),
  ('centre-lekie', 'centre', 'Lekie'),
  ('centre-mbam-et-inoubou', 'centre', 'Mbam-et-Inoubou'),
  ('centre-mbam-et-kim', 'centre', 'Mbam-et-Kim'),
  ('centre-mefou-et-afamba', 'centre', 'Mefou-et-Afamba'),
  ('centre-mefou-et-akono', 'centre', 'Mefou-et-Akono'),
  ('centre-mfoundi', 'centre', 'Mfoundi'),
  ('centre-nyong-et-kelle', 'centre', 'Nyong-et-Kelle'),
  ('centre-nyong-et-mfoumou', 'centre', 'Nyong-et-Mfoumou'),
  ('centre-nyong-et-soo', 'centre', 'Nyong-et-Soo'),
  ('east-boumba-et-ngoko', 'east', 'Boumba-et-Ngoko'),
  ('east-haut-nyong', 'east', 'Haut-Nyong'),
  ('east-kadey', 'east', 'Kadey'),
  ('east-lom-et-djerem', 'east', 'Lom-et-Djerem'),
  ('far-north-diamare', 'far-north', 'Diamare'),
  ('far-north-logone-et-chari', 'far-north', 'Logone-et-Chari'),
  ('far-north-mayo-danay', 'far-north', 'Mayo-Danay'),
  ('far-north-mayo-kani', 'far-north', 'Mayo-Kani'),
  ('far-north-mayo-sava', 'far-north', 'Mayo-Sava'),
  ('far-north-mayo-tsanaga', 'far-north', 'Mayo-Tsanaga'),
  ('littoral-moungo', 'littoral', 'Moungo'),
  ('littoral-nkam', 'littoral', 'Nkam'),
  ('littoral-sanaga-maritime', 'littoral', 'Sanaga-Maritime'),
  ('littoral-wouri', 'littoral', 'Wouri'),
  ('north-benoue', 'north', 'Benoue'),
  ('north-faro', 'north', 'Faro'),
  ('north-mayo-louti', 'north', 'Mayo-Louti'),
  ('north-mayo-rey', 'north', 'Mayo-Rey'),
  ('north-west-boyo', 'north-west', 'Boyo'),
  ('north-west-bui', 'north-west', 'Bui'),
  ('north-west-donga-mantung', 'north-west', 'Donga-Mantung'),
  ('north-west-mezam', 'north-west', 'Mezam'),
  ('north-west-menchum', 'north-west', 'Menchum'),
  ('north-west-momo', 'north-west', 'Momo'),
  ('north-west-ngoketunjia', 'north-west', 'Ngoketunjia'),
  ('south-dja-et-lobo', 'south', 'Dja-et-Lobo'),
  ('south-mvila', 'south', 'Mvila'),
  ('south-ocean', 'south', 'Ocean'),
  ('south-vallee-du-ntem', 'south', 'Vallee-du-Ntem'),
  ('south-west-fako', 'south-west', 'Fako'),
  ('south-west-kupe-manenguba', 'south-west', 'Kupe-Manenguba'),
  ('south-west-lebialem', 'south-west', 'Lebialem'),
  ('south-west-manyu', 'south-west', 'Manyu'),
  ('south-west-meme', 'south-west', 'Meme'),
  ('south-west-ndian', 'south-west', 'Ndian'),
  ('west-bamboutos', 'west', 'Bamboutos'),
  ('west-haut-nkam', 'west', 'Haut-Nkam'),
  ('west-hauts-plateaux', 'west', 'Hauts-Plateaux'),
  ('west-koung-khi', 'west', 'Koung-Khi'),
  ('west-menoua', 'west', 'Menoua'),
  ('west-mifi', 'west', 'Mifi'),
  ('west-nde', 'west', 'Nde'),
  ('west-noun', 'west', 'Noun')
ON CONFLICT (code) DO UPDATE
SET region_code = EXCLUDED.region_code,
    name = EXCLUDED.name;

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS settlement_mode
  transaction_settlement_mode NOT NULL DEFAULT 'platform_escrow';

CREATE TABLE IF NOT EXISTS user_preferences (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  locale VARCHAR(10) NOT NULL DEFAULT 'en',
  email_notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  sms_notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  push_notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  marketing_notifications_enabled BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payout_requests (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  payment_method_id BIGINT REFERENCES payment_methods(id) ON DELETE RESTRICT,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'XAF',
  status payout_request_status NOT NULL DEFAULT 'pending',
  reason VARCHAR(255),
  processor_reference VARCHAR(255),
  metadata JSONB,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transaction_settlement_declarations (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  declared_by_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  settlement_mode transaction_settlement_mode NOT NULL,
  payment_channel settlement_payment_channel NOT NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'XAF',
  payment_reference VARCHAR(255),
  provider_name VARCHAR(100),
  occurred_at TIMESTAMPTZ NOT NULL,
  status settlement_declaration_status NOT NULL DEFAULT 'pending_review',
  evidence JSONB,
  notes TEXT,
  reviewed_by_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transaction_settlement_confirmations (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  declaration_id BIGINT NOT NULL
    REFERENCES transaction_settlement_declarations(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status settlement_confirmation_status NOT NULL DEFAULT 'pending',
  note TEXT,
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (declaration_id, user_id)
);

CREATE TABLE IF NOT EXISTS transaction_legal_reviews (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  reviewer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  decision transaction_legal_review_decision NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_preferences_user
  ON user_preferences (user_id);

CREATE INDEX IF NOT EXISTS idx_payout_requests_user_status
  ON payout_requests (user_id, status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_transaction_declarations_transaction
  ON transaction_settlement_declarations (transaction_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transaction_declarations_status
  ON transaction_settlement_declarations (status, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_transaction_confirmations_declaration
  ON transaction_settlement_confirmations (declaration_id, status);

CREATE INDEX IF NOT EXISTS idx_transaction_legal_reviews_transaction
  ON transaction_legal_reviews (transaction_id, created_at DESC);

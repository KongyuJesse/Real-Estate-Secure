-- Real Estate Secure - Production schema (PostgreSQL)
-- Core schema aligned with Cameroonian real estate compliance workflows.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enumerations
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role_type') THEN
    CREATE TYPE user_role_type AS ENUM (
      'buyer',
      'seller',
      'landlord',
      'tenant',
      'lawyer',
      'surveyor',
      'agent',
      'admin',
      'super_admin'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'address_type') THEN
    CREATE TYPE address_type AS ENUM ('residential', 'legal', 'billing', 'shipping');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'identity_document_type') THEN
    CREATE TYPE identity_document_type AS ENUM (
      'national_id',
      'passport',
      'driver_license',
      'residence_permit'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status') THEN
    CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected', 'expired');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_method') THEN
    CREATE TYPE verification_method AS ENUM ('manual', 'automated', 'hybrid');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type') THEN
    CREATE TYPE business_type AS ENUM (
      'agency',
      'law_firm',
      'development_company',
      'individual'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_type') THEN
    CREATE TYPE property_type AS ENUM (
      'land',
      'house',
      'apartment',
      'commercial',
      'industrial',
      'agricultural'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'listing_type') THEN
    CREATE TYPE listing_type AS ENUM ('sale', 'rent', 'lease');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_status') THEN
    CREATE TYPE property_status AS ENUM (
      'draft',
      'pending',
      'active',
      'sold',
      'rented',
      'expired',
      'rejected',
      'archived'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_condition') THEN
    CREATE TYPE property_condition AS ENUM ('new', 'good', 'renovation_needed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'location_type') THEN
    CREATE TYPE location_type AS ENUM ('primary', 'additional', 'boundary');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_document_type') THEN
    CREATE TYPE property_document_type AS ENUM (
      'land_title',
      'survey_plan',
      'tax_clearance',
      'non_encumbrance',
      'sale_agreement',
      'building_permit',
      'certificate_of_habitation',
      'valuation_report'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_image_type') THEN
    CREATE TYPE property_image_type AS ENUM (
      'exterior',
      'interior',
      'kitchen',
      'bathroom',
      'bedroom',
      'living',
      'drone',
      'floor_plan',
      'virtual_tour'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'video_type') THEN
    CREATE TYPE video_type AS ENUM ('tour', 'drone', 'walkthrough', 'interview');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'watermark_status') THEN
    CREATE TYPE watermark_status AS ENUM ('pending', 'applied', 'skipped');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'access_level') THEN
    CREATE TYPE access_level AS ENUM ('public', 'verified_only', 'lawyer_only');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_type') THEN
    CREATE TYPE request_type AS ENUM ('initial', 'appeal', 'update');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_status') THEN
    CREATE TYPE request_status AS ENUM ('pending', 'in_review', 'approved', 'rejected', 'escalated');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'priority_level') THEN
    CREATE TYPE priority_level AS ENUM ('low', 'normal', 'medium', 'high', 'urgent');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_step_type') THEN
    CREATE TYPE verification_step_type AS ENUM (
      'document_check',
      'ownership_verification',
      'site_visit',
      'legal_review'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_step_status') THEN
    CREATE TYPE verification_step_status AS ENUM (
      'pending',
      'in_progress',
      'completed',
      'skipped',
      'blocked'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type') THEN
    CREATE TYPE transaction_type AS ENUM ('sale', 'rent', 'lease');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_status') THEN
    CREATE TYPE transaction_status AS ENUM (
      'initiated',
      'pending_deposit',
      'deposited',
      'documents_pending',
      'documents_verified',
      'inspection_period',
      'lawyer_approval',
      'completed',
      'disputed',
      'cancelled',
      'refunded'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'escrow_account_status') THEN
    CREATE TYPE escrow_account_status AS ENUM ('active', 'held', 'released', 'closed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'escrow_transaction_type') THEN
    CREATE TYPE escrow_transaction_type AS ENUM ('deposit', 'withdrawal', 'hold', 'release', 'refund', 'fee');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'escrow_transaction_status') THEN
    CREATE TYPE escrow_transaction_status AS ENUM ('pending', 'completed', 'failed', 'cancelled');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method_type') THEN
    CREATE TYPE payment_method_type AS ENUM ('momo', 'orange', 'bank_card', 'bank_transfer');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_provider') THEN
    CREATE TYPE payment_provider AS ENUM ('mtn', 'orange', 'visa', 'mastercard', 'ecobank', 'sgc');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_type') THEN
    CREATE TYPE invoice_type AS ENUM ('platform_fee', 'legal_fee', 'subscription', 'deposit');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
    CREATE TYPE invoice_status AS ENUM ('draft', 'pending', 'paid', 'overdue', 'cancelled', 'refunded');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'billing_cycle') THEN
    CREATE TYPE billing_cycle AS ENUM ('monthly', 'yearly');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
    CREATE TYPE subscription_status AS ENUM ('active', 'pending', 'expired', 'cancelled', 'suspended');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_invoice_status') THEN
    CREATE TYPE subscription_invoice_status AS ENUM ('pending', 'paid', 'failed', 'refunded');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dispute_type') THEN
    CREATE TYPE dispute_type AS ENUM (
      'document_fraud',
      'title_dispute',
      'payment_dispute',
      'property_condition',
      'other'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dispute_status') THEN
    CREATE TYPE dispute_status AS ENUM ('open', 'investigating', 'resolved', 'escalated', 'closed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_type') THEN
    CREATE TYPE conversation_type AS ENUM ('direct', 'group', 'property', 'transaction');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'participant_role') THEN
    CREATE TYPE participant_role AS ENUM ('participant', 'admin', 'lawyer');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_type') THEN
    CREATE TYPE message_type AS ENUM ('text', 'image', 'file', 'offer', 'location', 'contact');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_delivery_status') THEN
    CREATE TYPE message_delivery_status AS ENUM ('sent', 'delivered', 'read');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_frequency') THEN
    CREATE TYPE notification_frequency AS ENUM ('realtime', 'daily', 'weekly');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_verification_type') THEN
    CREATE TYPE document_verification_type AS ENUM ('manual', 'automated', 'expert');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_verification_action') THEN
    CREATE TYPE document_verification_action AS ENUM (
      'submitted',
      'viewed',
      'verified',
      'rejected',
      'appealed'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lawyer_review_status') THEN
    CREATE TYPE lawyer_review_status AS ENUM ('pending', 'published', 'rejected', 'hidden');
  END IF;
END $$;

-- Core user management
CREATE TABLE IF NOT EXISTS users (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  phone_number VARCHAR(20) UNIQUE NOT NULL,
  phone_country_code VARCHAR(5) DEFAULT '+237',
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  date_of_birth DATE NOT NULL,
  nationality VARCHAR(50) DEFAULT 'Cameroonian',
  profile_image_url TEXT,
  bio TEXT,
  preferred_language VARCHAR(10) DEFAULT 'en',
  two_factor_enabled BOOLEAN DEFAULT false,
  two_factor_secret VARCHAR(255),
  email_verified_at TIMESTAMPTZ,
  phone_verified_at TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,
  last_login_ip INET,
  failed_login_attempts SMALLINT DEFAULT 0,
  locked_until TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  is_suspended BOOLEAN DEFAULT false,
  suspension_reason TEXT,
  terms_accepted_at TIMESTAMPTZ NOT NULL,
  privacy_accepted_at TIMESTAMPTZ NOT NULL,
  marketing_consent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS user_roles (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role user_role_type NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  expires_at TIMESTAMPTZ,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS user_addresses (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  address_type address_type NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  country VARCHAR(50) DEFAULT 'Cameroon',
  region VARCHAR(100) NOT NULL,
  department VARCHAR(100),
  city VARCHAR(100) NOT NULL,
  district VARCHAR(100),
  postal_code VARCHAR(20),
  street_address VARCHAR(255) NOT NULL,
  landmark VARCHAR(255),
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  property_tax_region VARCHAR(50),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- KYC & verification
CREATE TABLE IF NOT EXISTS identity_documents (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  document_type identity_document_type NOT NULL,
  document_number VARCHAR(100) NOT NULL,
  issuing_country VARCHAR(50) DEFAULT 'Cameroon',
  issuing_authority VARCHAR(100),
  issue_date DATE NOT NULL,
  expiry_date DATE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  front_image_path TEXT NOT NULL,
  back_image_path TEXT,
  portrait_image_path TEXT,
  verification_status verification_status DEFAULT 'pending',
  verification_method verification_method,
  verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  verified_at TIMESTAMPTZ,
  rejection_reason TEXT,
  rejection_details JSONB,
  risk_score DECIMAL(3, 2),
  fraud_check_id VARCHAR(100),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS business_verifications (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  business_name VARCHAR(255) NOT NULL,
  business_registration_number VARCHAR(100) NOT NULL,
  tax_id_number VARCHAR(100) NOT NULL,
  business_type business_type NOT NULL,
  registration_certificate_path TEXT NOT NULL,
  tax_clearance_path TEXT NOT NULL,
  articles_of_association_path TEXT,
  business_license_path TEXT,
  registered_address TEXT NOT NULL,
  date_of_registration DATE NOT NULL,
  verification_status verification_status DEFAULT 'pending',
  verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  verified_at TIMESTAMPTZ,
  expiry_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS biometric_registrations (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  credential_id VARCHAR(255) UNIQUE NOT NULL,
  public_key TEXT NOT NULL,
  sign_count BIGINT DEFAULT 0,
  device_name VARCHAR(255),
  device_type VARCHAR(50),
  last_used_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Property management
CREATE TABLE IF NOT EXISTS properties (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  listed_by_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  property_type property_type NOT NULL,
  listing_type listing_type NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  short_description VARCHAR(500),
  property_status property_status DEFAULT 'draft',
  verification_status verification_status DEFAULT 'pending',
  price DECIMAL(15, 2) NOT NULL CHECK (price >= 0),
  price_sqft DECIMAL(10, 2),
  platform_fee_percentage DECIMAL(5, 2) DEFAULT 5.00,
  platform_fee_amount DECIMAL(15, 2),
  total_price_buyer DECIMAL(15, 2),
  currency VARCHAR(3) DEFAULT 'XAF',
  land_size DECIMAL(10, 2),
  land_size_unit VARCHAR(10) DEFAULT 'sqm',
  build_size DECIMAL(10, 2),
  bedrooms SMALLINT,
  bathrooms DECIMAL(3, 1),
  floor_count SMALLINT,
  year_built SMALLINT,
  condition property_condition,
  furnished BOOLEAN DEFAULT false,
  amenities JSONB,
  utilities_included JSONB,
  zoning_type VARCHAR(100),
  land_use VARCHAR(100),
  is_featured BOOLEAN DEFAULT false,
  featured_until TIMESTAMPTZ,
  view_count INT DEFAULT 0,
  unique_view_count INT DEFAULT 0,
  inquiry_count INT DEFAULT 0,
  last_viewed_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS property_locations (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  location_type location_type DEFAULT 'primary',
  country VARCHAR(50) DEFAULT 'Cameroon',
  region VARCHAR(100) NOT NULL,
  department VARCHAR(100) NOT NULL,
  city VARCHAR(100) NOT NULL,
  district VARCHAR(100),
  neighborhood VARCHAR(100),
  street_address VARCHAR(255),
  landmark VARCHAR(255),
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  geohash VARCHAR(12),
  google_place_id VARCHAR(255),
  cadastral_reference VARCHAR(100),
  lot_number VARCHAR(50),
  block_number VARCHAR(50),
  plot_number VARCHAR(50),
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_documents (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  document_type property_document_type NOT NULL,
  document_number VARCHAR(100) NOT NULL,
  document_title VARCHAR(255) NOT NULL,
  issuing_authority VARCHAR(255) NOT NULL,
  issue_date DATE NOT NULL,
  expiry_date DATE,
  file_path TEXT NOT NULL,
  file_hash CHAR(64) NOT NULL,
  file_size INT NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  is_verified BOOLEAN DEFAULT false,
  verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  verified_at TIMESTAMPTZ,
  verification_notes TEXT,
  rejection_reason TEXT,
  is_public BOOLEAN DEFAULT false,
  access_level access_level DEFAULT 'verified_only',
  watermark_text TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_images (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  image_type property_image_type DEFAULT 'exterior',
  sort_order SMALLINT DEFAULT 0,
  is_primary BOOLEAN DEFAULT false,
  title VARCHAR(255),
  description TEXT,
  file_path_original TEXT NOT NULL,
  file_path_large TEXT,
  file_path_medium TEXT,
  file_path_small TEXT,
  file_path_thumbnail TEXT,
  file_hash CHAR(64) NOT NULL,
  file_size INT NOT NULL,
  width INT,
  height INT,
  mime_type VARCHAR(100) NOT NULL,
  gps_latitude DECIMAL(10, 8),
  gps_longitude DECIMAL(11, 8),
  taken_at TIMESTAMPTZ,
  is_verified BOOLEAN DEFAULT false,
  ai_moderation_score DECIMAL(3, 2),
  ai_moderation_flags JSONB,
  watermark_status watermark_status DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_videos (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  video_type video_type DEFAULT 'tour',
  file_path TEXT NOT NULL,
  thumbnail_path TEXT,
  duration INT,
  file_size BIGINT NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  youtube_id VARCHAR(50),
  vimeo_id VARCHAR(50),
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Legal & verification
CREATE TABLE IF NOT EXISTS land_titles (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  title_number VARCHAR(100) UNIQUE NOT NULL,
  volume_number VARCHAR(50),
  folio_number VARCHAR(50),
  registration_date DATE NOT NULL,
  registration_office VARCHAR(255) NOT NULL,
  registrar_name VARCHAR(255) NOT NULL,
  prior_title_number VARCHAR(100),
  land_area_hectares DECIMAL(15, 5) NOT NULL,
  land_area_sqm DECIMAL(15, 2) NOT NULL,
  boundaries_description TEXT NOT NULL,
  cadastral_section VARCHAR(50),
  cadastral_plan_number VARCHAR(100),
  surveyor_name VARCHAR(255),
  surveyor_certification VARCHAR(100),
  previous_owners JSONB,
  current_owner_name VARCHAR(255) NOT NULL,
  owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  encumbrances JSONB,
  is_original BOOLEAN DEFAULT true,
  document_hash CHAR(64) NOT NULL,
  blockchain_tx_id VARCHAR(255),
  verification_status verification_status DEFAULT 'pending',
  verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_verification_requests (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  requester_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assigned_to_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  request_type request_type NOT NULL,
  status request_status DEFAULT 'pending',
  priority priority_level DEFAULT 'normal',
  submitted_at TIMESTAMPTZ DEFAULT now(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  review_deadline TIMESTAMPTZ,
  reviewer_notes TEXT,
  rejection_reason TEXT,
  rejection_category VARCHAR(100),
  appeal_count SMALLINT DEFAULT 0,
  escalation_level SMALLINT DEFAULT 0,
  escalated_to_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS property_verification_steps (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  request_id BIGINT NOT NULL REFERENCES property_verification_requests(id) ON DELETE RESTRICT,
  step_name VARCHAR(100) NOT NULL,
  step_type verification_step_type NOT NULL,
  status verification_step_status DEFAULT 'pending',
  assigned_to_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  notes TEXT,
  attachments JSONB,
  duration_minutes INT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Transaction & escrow
CREATE TABLE IF NOT EXISTS transactions (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  transaction_number VARCHAR(50) UNIQUE NOT NULL,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  buyer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  seller_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  lawyer_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  transaction_type transaction_type NOT NULL,
  transaction_status transaction_status DEFAULT 'initiated',
  property_price DECIMAL(15, 2) NOT NULL CHECK (property_price >= 0),
  platform_fee_percentage DECIMAL(5, 2) DEFAULT 5.00,
  platform_fee_amount DECIMAL(15, 2) NOT NULL CHECK (platform_fee_amount >= 0),
  lawyer_fee DECIMAL(15, 2),
  legal_fees DECIMAL(15, 2),
  total_amount DECIMAL(15, 2) NOT NULL CHECK (total_amount >= 0),
  currency VARCHAR(3) DEFAULT 'XAF',
  deposit_amount DECIMAL(15, 2),
  deposit_due_date TIMESTAMPTZ,
  deposit_received_date TIMESTAMPTZ,
  completion_date TIMESTAMPTZ,
  inspection_period_days SMALLINT DEFAULT 2,
  inspection_end_date TIMESTAMPTZ,
  dispute_deadline TIMESTAMPTZ,
  cancellation_reason TEXT,
  cancellation_by_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_methods (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  method_type payment_method_type NOT NULL,
  provider payment_provider NOT NULL,
  account_name VARCHAR(255),
  account_number VARCHAR(100),
  phone_number VARCHAR(20),
  card_last_four CHAR(4),
  card_expiry_month CHAR(2),
  card_expiry_year CHAR(4),
  bank_name VARCHAR(100),
  bank_code VARCHAR(20),
  is_default BOOLEAN DEFAULT false,
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  billing_address_id BIGINT REFERENCES user_addresses(id) ON DELETE RESTRICT,
  payment_token VARCHAR(255),
  provider_customer_id VARCHAR(255),
  metadata JSONB,
  last_used_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS escrow_accounts (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE RESTRICT,
  account_number VARCHAR(50) UNIQUE NOT NULL,
  account_status escrow_account_status DEFAULT 'active',
  current_balance DECIMAL(15, 2) DEFAULT 0.00,
  total_deposited DECIMAL(15, 2) DEFAULT 0.00,
  total_withdrawn DECIMAL(15, 2) DEFAULT 0.00,
  held_balance DECIMAL(15, 2) DEFAULT 0.00,
  available_balance DECIMAL(15, 2) DEFAULT 0.00,
  last_transaction_at TIMESTAMPTZ,
  release_conditions JSONB,
  release_date TIMESTAMPTZ,
  released_to_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS escrow_transactions (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  escrow_account_id BIGINT NOT NULL REFERENCES escrow_accounts(id) ON DELETE RESTRICT,
  transaction_reference VARCHAR(100) UNIQUE NOT NULL,
  transaction_type escrow_transaction_type NOT NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount >= 0),
  balance_before DECIMAL(15, 2) NOT NULL,
  balance_after DECIMAL(15, 2) NOT NULL,
  payment_method_id BIGINT REFERENCES payment_methods(id) ON DELETE RESTRICT,
  payment_provider payment_provider NOT NULL,
  provider_reference VARCHAR(255),
  status escrow_transaction_status DEFAULT 'pending',
  description TEXT,
  initiated_by_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  approved_by_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  approved_at TIMESTAMPTZ,
  failure_reason TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS invoices (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  invoice_number VARCHAR(50) UNIQUE NOT NULL,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  transaction_id BIGINT REFERENCES transactions(id) ON DELETE RESTRICT,
  invoice_type invoice_type NOT NULL,
  status invoice_status DEFAULT 'pending',
  issue_date DATE NOT NULL,
  due_date DATE NOT NULL,
  paid_date TIMESTAMPTZ,
  subtotal DECIMAL(15, 2) NOT NULL CHECK (subtotal >= 0),
  tax_amount DECIMAL(15, 2) DEFAULT 0.00,
  tax_rate DECIMAL(5, 2) DEFAULT 19.25,
  total_amount DECIMAL(15, 2) NOT NULL CHECK (total_amount >= 0),
  currency VARCHAR(3) DEFAULT 'XAF',
  pdf_path TEXT,
  payment_terms VARCHAR(255),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Subscriptions & billing
CREATE TABLE IF NOT EXISTS subscription_plans (
  id SMALLINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  plan_name VARCHAR(50) UNIQUE NOT NULL,
  plan_code VARCHAR(20) UNIQUE NOT NULL,
  price_monthly DECIMAL(10, 2) NOT NULL CHECK (price_monthly >= 0),
  price_yearly DECIMAL(10, 2),
  currency VARCHAR(3) DEFAULT 'XAF',
  max_listings SMALLINT NOT NULL,
  max_photos_per_listing SMALLINT NOT NULL,
  max_videos_per_listing SMALLINT DEFAULT 0,
  featured_listings_included SMALLINT DEFAULT 0,
  transaction_fee_percentage DECIMAL(4, 2) NOT NULL,
  priority_support BOOLEAN DEFAULT false,
  analytics_access BOOLEAN DEFAULT false,
  api_access BOOLEAN DEFAULT false,
  bulk_listing_tools BOOLEAN DEFAULT false,
  company_profile BOOLEAN DEFAULT false,
  badge_display VARCHAR(50),
  is_active BOOLEAN DEFAULT true,
  sort_order SMALLINT NOT NULL,
  description TEXT NOT NULL,
  features JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  plan_id SMALLINT NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
  subscription_status subscription_status DEFAULT 'active',
  billing_cycle billing_cycle NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  next_billing_date DATE NOT NULL,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  auto_renew BOOLEAN DEFAULT true,
  price_paid DECIMAL(10, 2) NOT NULL CHECK (price_paid >= 0),
  currency VARCHAR(3) DEFAULT 'XAF',
  payment_method_id BIGINT REFERENCES payment_methods(id) ON DELETE RESTRICT,
  listing_count_used SMALLINT DEFAULT 0,
  listing_count_limit SMALLINT NOT NULL,
  featured_count_used SMALLINT DEFAULT 0,
  featured_count_limit SMALLINT NOT NULL,
  grace_period_end DATE,
  suspension_reason TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscription_invoices (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  subscription_id BIGINT NOT NULL REFERENCES user_subscriptions(id) ON DELETE RESTRICT,
  invoice_number VARCHAR(50) UNIQUE NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
  tax_amount DECIMAL(10, 2) DEFAULT 0.00,
  total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
  status subscription_invoice_status DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  payment_method_id BIGINT REFERENCES payment_methods(id) ON DELETE RESTRICT,
  payment_reference VARCHAR(255),
  pdf_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Lawyer & professional services
CREATE TABLE IF NOT EXISTS lawyer_profiles (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  bar_number VARCHAR(50) UNIQUE NOT NULL,
  bar_admission_date DATE NOT NULL,
  bar_council VARCHAR(255) NOT NULL,
  law_firm_name VARCHAR(255),
  law_firm_address TEXT,
  years_of_experience SMALLINT NOT NULL,
  specialization JSONB NOT NULL,
  languages JSONB NOT NULL,
  consultation_fee DECIMAL(10, 2),
  fixed_fee_services JSONB,
  service_regions JSONB NOT NULL,
  availability JSONB,
  average_rating DECIMAL(3, 2) DEFAULT 0.00,
  total_reviews INT DEFAULT 0,
  successful_cases INT DEFAULT 0,
  verification_status verification_status DEFAULT 'pending',
  verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  verified_at TIMESTAMPTZ,
  certificate_path TEXT NOT NULL,
  insurance_certificate_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lawyer_reviews (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  lawyer_id BIGINT NOT NULL REFERENCES lawyer_profiles(id) ON DELETE RESTRICT,
  reviewer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE RESTRICT,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title VARCHAR(255),
  review_text TEXT NOT NULL,
  professionalism_rating SMALLINT,
  communication_rating SMALLINT,
  responsiveness_rating SMALLINT,
  value_rating SMALLINT,
  is_verified_purchase BOOLEAN DEFAULT true,
  is_anonymous BOOLEAN DEFAULT false,
  status lawyer_review_status DEFAULT 'published',
  moderator_notes TEXT,
  helpful_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (lawyer_id, reviewer_id, transaction_id)
);

CREATE TABLE IF NOT EXISTS surveyor_profiles (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  license_number VARCHAR(50) UNIQUE NOT NULL,
  license_issuing_authority VARCHAR(255) NOT NULL,
  license_expiry DATE NOT NULL,
  years_experience SMALLINT NOT NULL,
  equipment_owned JSONB,
  service_regions JSONB NOT NULL,
  certification_path TEXT NOT NULL,
  insurance_path TEXT,
  verification_status verification_status DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Messaging & communication
CREATE TABLE IF NOT EXISTS conversations (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  property_id BIGINT REFERENCES properties(id) ON DELETE RESTRICT,
  transaction_id BIGINT REFERENCES transactions(id) ON DELETE RESTRICT,
  conversation_type conversation_type NOT NULL,
  title VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  last_message_at TIMESTAMPTZ,
  last_message_preview VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE RESTRICT,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role participant_role DEFAULT 'participant',
  joined_at TIMESTAMPTZ DEFAULT now(),
  left_at TIMESTAMPTZ,
  last_read_at TIMESTAMPTZ,
  is_muted BOOLEAN DEFAULT false,
  is_archived BOOLEAN DEFAULT false,
  notification_preferences JSONB,
  UNIQUE (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE RESTRICT,
  sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  message_type message_type DEFAULT 'text',
  content TEXT NOT NULL,
  attachments JSONB,
  offer_data JSONB,
  location_data JSONB,
  is_system_message BOOLEAN DEFAULT false,
  is_edited BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  client_metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS message_status (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  message_id BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status message_delivery_status DEFAULT 'sent',
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (message_id, user_id)
);

-- Favorites & saved searches
CREATE TABLE IF NOT EXISTS favorites (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  notes TEXT,
  folder_name VARCHAR(100) DEFAULT 'default',
  notification_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, property_id)
);

CREATE TABLE IF NOT EXISTS saved_searches (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  search_name VARCHAR(255) NOT NULL,
  search_criteria JSONB NOT NULL,
  notification_frequency notification_frequency DEFAULT 'daily',
  last_notified_at TIMESTAMPTZ,
  new_matches_count INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Audit & security
CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id BIGINT NOT NULL,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  session_id VARCHAR(255),
  request_id VARCHAR(100),
  response_time_ms INT,
  status_code SMALLINT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS login_attempts (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  email VARCHAR(255),
  user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  ip_address INET NOT NULL,
  user_agent TEXT,
  success BOOLEAN DEFAULT false,
  failure_reason VARCHAR(255),
  two_factor_used BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS api_keys (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name VARCHAR(255) NOT NULL,
  key_hash CHAR(64) UNIQUE NOT NULL,
  key_preview CHAR(8) NOT NULL,
  permissions JSONB NOT NULL,
  allowed_ips JSONB,
  last_used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS document_verification_logs (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  document_id BIGINT NOT NULL REFERENCES property_documents(id) ON DELETE CASCADE,
  verifier_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  verification_type document_verification_type NOT NULL,
  action document_verification_action NOT NULL,
  notes TEXT,
  confidence_score DECIMAL(3, 2),
  flags JSONB,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Disputes
CREATE TABLE IF NOT EXISTS disputes (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  dispute_number VARCHAR(50) UNIQUE NOT NULL,
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE RESTRICT,
  raised_by_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  raised_against_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  dispute_type dispute_type NOT NULL,
  status dispute_status DEFAULT 'open',
  priority priority_level DEFAULT 'medium',
  description TEXT NOT NULL,
  evidence_documents JSONB,
  requested_resolution TEXT NOT NULL,
  assigned_to_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ,
  resolution_decision TEXT,
  resolution_date TIMESTAMPTZ,
  resolved_by_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  appeal_deadline TIMESTAMPTZ,
  appeal_filed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dispute_messages (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  dispute_id BIGINT NOT NULL REFERENCES disputes(id) ON DELETE RESTRICT,
  sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  message TEXT NOT NULL,
  attachments JSONB,
  is_private BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Analytics
CREATE TABLE IF NOT EXISTS property_views (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  session_id VARCHAR(100),
  ip_address INET,
  user_agent TEXT,
  referrer TEXT,
  view_duration_seconds INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS search_analytics (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  session_id VARCHAR(100),
  search_query VARCHAR(255),
  filters_applied JSONB NOT NULL,
  result_count INT NOT NULL,
  clicked_property_id BIGINT REFERENCES properties(id) ON DELETE SET NULL,
  click_position SMALLINT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- System configuration
CREATE TABLE IF NOT EXISTS system_settings (
  id SMALLINT PRIMARY KEY,
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value JSONB NOT NULL,
  description TEXT,
  is_encrypted BOOLEAN DEFAULT false,
  updated_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS email_templates (
  id SMALLINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  template_name VARCHAR(100) UNIQUE NOT NULL,
  subject_en VARCHAR(255) NOT NULL,
  subject_fr VARCHAR(255) NOT NULL,
  body_en TEXT NOT NULL,
  body_fr TEXT NOT NULL,
  variables JSONB NOT NULL,
  attachments JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms_templates (
  id SMALLINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  template_name VARCHAR(100) UNIQUE NOT NULL,
  body_en VARCHAR(160) NOT NULL,
  body_fr VARCHAR(160) NOT NULL,
  variables JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Currency and exchange rates
CREATE TABLE IF NOT EXISTS currencies (
  code VARCHAR(3) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  symbol VARCHAR(10),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS exchange_rates (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  base_currency VARCHAR(3) NOT NULL REFERENCES currencies(code) ON DELETE RESTRICT,
  quote_currency VARCHAR(3) NOT NULL REFERENCES currencies(code) ON DELETE RESTRICT,
  rate DECIMAL(18, 8) NOT NULL CHECK (rate > 0),
  effective_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (base_currency, quote_currency, effective_at)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_status_created ON users(is_active, created_at);
CREATE INDEX IF NOT EXISTS idx_properties_status_type ON properties(property_status, property_type);
CREATE INDEX IF NOT EXISTS idx_properties_price ON properties(price);
CREATE INDEX IF NOT EXISTS idx_properties_owner ON properties(owner_id);
CREATE INDEX IF NOT EXISTS idx_properties_verification ON properties(verification_status);
CREATE INDEX IF NOT EXISTS idx_property_locations_geo ON property_locations(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_property_locations_geohash ON property_locations(geohash);
CREATE INDEX IF NOT EXISTS idx_transactions_buyer ON transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_seller ON transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(transaction_status);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_user_created ON audit_logs(user_id, created_at);


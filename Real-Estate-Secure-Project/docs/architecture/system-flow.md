# Real Estate Secure - System Flow and Production Blueprint

## Executive Summary

Real Estate Secure is a legally verified, evidence-driven real estate platform
for Cameroon. The production system is designed around a low-risk marketplace
model:

- the platform is a verified marketplace, escrow ledger, evidence vault, and
  workflow coordinator
- the platform is not the transfer agent
- sale closings are notary-led
- lawyer review is selective and risk-based
- government-light sale inventory is the default marketplace lane
- monetization comes from subscriptions and paid services, not sale-value fees

## Core Promise

Verified property intake, auditable money flow, and documentary closing
evidence, without pretending the platform itself performs government transfer
steps.

## Production Updates Reflected in the Current System

- Cameroon phone, region, department, and coordinate validation run before
  user, KYC, property, and payout writes are accepted.
- Off-platform and hybrid settlements are governed first-class flows.
- Sale listings are screened into `government_light`, `assisted_only`, or
  `blocked` lanes before they can reach the ordinary marketplace.
- Assisted sale files now carry explicit offline-step and legal-case records
  for court, ministry, cadastral, commission, and notary-office follow-up.
- Transactions can be `automation_frozen` with a stored reason while court or
  ministry blockers remain open.
- Sale files use explicit closing stages:
  `commercially_closed`, `notarial_deed_signed`, `mutation_filed`,
  `title_transfer_confirmed`.
- Notary assignment is independent from lawyer assignment.
- Revenue is modeled through service catalog and subscription products.

## System Structure

Clients (Flutter mobile, web, admin)
        |
        v
API Gateway (Dart + Shelf)
        |
        +--> Auth, Users, Roles, KYC
        +--> Properties, Locations, Documents, Admission
        +--> Transactions, Escrow, External Settlements
        +--> Lawyers, Notaries, Compliance, Disputes
        +--> Messaging, Notifications
        +--> Paid Services, Promotions, Compliance Packs
        +--> Admin, Analytics, Fraud, Reconciliation
        |
        v
PostgreSQL (primary system of record)
Object Storage (documents, images, videos)
CDN (signed delivery for public and verified assets)
Redis (caching, rate limits, sessions)
Queue + Workers (verification, indexing, notifications, retention)
Search Index (Postgres FTS or Elasticsearch)
Observability (logs, metrics, traces)

## Role Model

Primary production roles:

- Admin
- Buyer
- Seller
- Lawyer
- Notary

Legacy roles remain possible in the schema, but the current transaction path is
centered on these roles. Users can hold multiple roles and choose a primary
role for the dashboard.

## Role Goals and Core Capabilities

**Buyer**
- Goal: Find an eligible property and complete a safe purchase or rental.
- Core capabilities: search or map discovery, request documents, initiate
  transaction, choose settlement mode, inspect, dispute, and follow closing
  progress.

**Seller**
- Goal: List admissible property, prove ownership, and receive compliant
  payment.
- Core capabilities: create listings, upload legal documents, respond to
  buyers, coordinate evidence tasks, and track transaction progress.

**Lawyer**
- Goal: Protect parties on files that require or request legal review.
- Core capabilities: review complex documents, review settlement declarations,
  issue legal decisions, and mediate disputes.

**Notary**
- Goal: Lead sale closings through deed, registration, and title-mutation
  evidence.
- Core capabilities: review closing readiness, confirm deed evidence, advance
  closing stages, and track title-transfer evidence.

**Admin**
- Goal: Maintain marketplace integrity and compliance.
- Core capabilities: moderate listings and KYC, approve high-value release,
  monitor fraud and reconciliation, and manage service backlog.

## End-to-End Flow

1. User registers and verifies identity.
2. User selects or activates the relevant role.
3. Seller creates a listing and uploads evidence.
4. Sale listing passes admission screening before it can be published.
5. Buyer discovers an eligible listing and initiates a transaction.
6. Transaction legal requirements are computed from case facts.
7. Parties assign a notary for sale files and a lawyer when required.
8. Funds move through escrow or are declared through governed external
   settlement.
9. Inspection, disputes, and legal review run as needed.
10. Notary-led closing evidence advances the sale through explicit stages.
11. Release or refund occurs only when rules are satisfied.
12. Audit logs, task feeds, and evidence history remain attached throughout.

## Key Business Workflows

### Onboarding

Register -> Verify Email and Phone -> KYC Upload -> Role Activation -> Dashboard

Mandatory outcomes:

- user identity evidence stored
- verification status tracked
- role state and risk flags recorded

### Property Listing and Admission

Create Listing -> Validate Cameroon Location -> Upload Documents -> Evaluate
Admission -> Verify -> Publish

Low-risk sale lane expects:

- titled private property
- recent certificate of property
- urbanism certificate
- accessibility certificate
- clear seller identity
- no declared dispute or encumbrance
- no foreign-party involvement

Files such as untitled/customary land, domain national allocations, succession,
foreign-party, disputed, encumbered, and judgment-driven sales are blocked or
diverted into assisted handling.

### Buyer Purchase

Discover Listing -> Initiate Transaction -> Deposit or Declare Settlement ->
Inspect -> Review Evidence -> Release, Refund, or Hold

Key checks:

- admission and verification status
- document authenticity and seller identity
- inspection and dispute window
- legal requirement level
- closing stage for sale files
- automation freeze state, offline step queue, and legal-case queue for
  assisted files

### Cameroon Sale Closing

Prepare Dossier -> Secure Commercial Close -> Assign Notary -> Sign Notarial
Deed -> Register Deed / File Mutation -> Upload Updated Title Evidence ->
Release or Complete

Explicit stages:

- `commercially_closed`
- `notarial_deed_signed`
- `mutation_filed`
- `title_transfer_confirmed`

Key checks:

- recent certificate of property
- urbanism and accessibility certificates
- tax and municipal certificates where applicable
- notary assignment for sale files
- lawyer review when foreign, disputed, encumbered, succession, corporate, or
  external-settlement conditions exist

### Assisted Physical and Court-Linked Workflow

Marketplace or matched sale -> Assisted lane intake -> Seed offline steps and
legal cases -> Freeze normal automation where needed -> Capture stamped or
certified evidence -> Track follow-up dates -> Clear blockers -> Resume
notary-led closing

Offline step types currently modeled:

- `notary_office_step`
- `municipal_certificate_step`
- `tax_registration_step`
- `mindcaf_filing_step`
- `court_case_step`
- `justice_execution_step`
- `commission_visit_step`
- `cadastral_validation_step`

Legal-case workflows currently modeled:

- `administrative_appeal`
- `administrative_litigation`
- `justice_execution`
- `succession_case`
- `judgment_enforcement`
- `domain_national_allocation`
- `old_title_regularization`
- `foreign_party_authorization`

Physical evidence controls now supported:

- stamped filing receipts
- hearing notices and clerk-issued documents
- certified judgment copies
- certificate of non-appeal or non-opposition evidence
- ministerial non-objection evidence
- site-visit reports and commission minutes
- original-seen and certified-copy metadata on uploaded documents

### External or Hybrid Settlement

Initiate Transaction -> Declare Settlement -> Upload Payment or Notary Evidence
-> Counterparty Confirmation -> Lawyer/Admin Review -> Commercial Close or Flag

Key checks:

- payment channel is recorded
- evidence is attached as transaction documents
- counterparties can confirm or reject the declaration
- review decisions are auditable
- commercial close does not equal title transfer

### Lawyer Verification

Assign Case -> Review Documents -> Approve or Reject -> Update Status -> Notify
Parties

Lawyer review is selective, not universal. It becomes required for cases such
as foreign-party, succession, corporate, power-of-attorney, encumbered,
disputed, judgment-driven, or off-platform settlement files.

### Dispute Resolution

Open Dispute -> Freeze Release -> Review Evidence -> Mediate -> Resolve -> Audit

### Subscription and Service Lifecycle

Select Plan -> Activate -> Track Usage -> Renew or Upgrade

Browse Service Catalog -> Create Service Order -> Pay -> Fulfill -> Audit

Monetization is service-based:

- subscriptions
- verification bundles
- document vault
- featured listings
- premium ads
- developer workspace
- lawyer and notary matching
- foreign-buyer compliance packs

## Production Pipelines and Controls

### KYC and OCR Integration

Upload -> Encrypt -> Provider Review -> Risk Score -> Manual Review -> Status
Update

### Document Storage Pipeline

Upload -> Hash -> Encrypt -> Store -> Watermark/Redaction Policy -> Signed
Access -> Audit

### Escrow Ledger Automation

Initiate -> Deposit -> Hold -> Release or Refund

Controls:

- idempotent money operations
- immutable ledger records
- reconciliation support
- four-eyes approval for high-value release

### Legal Transfer Evidence

Commercial Close -> Notary Deed -> Registration Receipt -> Mutation Evidence ->
Updated Title Evidence

Controls:

- no direct government integration
- evidence-based closing
- sale release blocked until title-transfer confirmation exists

### Notification Service

Event -> Outbox -> Worker -> Provider -> Delivery Status

### FX Rate Automation

Schedule -> Fetch Provider Rates -> Normalize to XAF -> Upsert Exchange Rates

### Search and Analytics

Track Views and Searches -> Score Abuse -> Aggregate Metrics

### Background Jobs

- KYC verification jobs
- notification dispatch jobs
- property indexing jobs
- retention and archive jobs
- reconciliation jobs

## Current API Surface (v1)

Auth
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/forgot-password
POST /auth/reset-password
POST /auth/2fa/enable
POST /auth/2fa/verify
POST /auth/biometric/register
POST /auth/biometric/verify

Users
POST /users/contact-verification/session
POST /users/contact-verification/refresh
GET /users
GET /users/profile
PUT /users/profile
GET /users/tasks
GET /users/roles
POST /users/roles
PUT /users/roles/primary
GET /users/{id}
GET /users/{id}/listings
GET /users/{id}/transactions
GET /users/{id}/reviews
POST /users/kyc/upload
GET /users/kyc/status
PUT /users/preferences
DELETE /users/account

Properties
GET /properties
GET /properties/search
GET /properties/map
GET /properties/{id}
GET /properties/{id}/status
POST /properties
PUT /properties/{id}
DELETE /properties/{id}
POST /properties/{id}/documents

Transactions
GET /transactions
GET /transactions/{id}
GET /transactions/{id}/compliance
POST /transactions/initiate
POST /transactions/{id}/deposit
POST /transactions/{id}/lawyer
POST /transactions/{id}/notary
POST /transactions/{id}/closing-stage
POST /transactions/{id}/inspect
POST /transactions/{id}/approve
POST /transactions/{id}/release
POST /transactions/{id}/hold
POST /transactions/{id}/refund
POST /transactions/{id}/documents
GET /transactions/{id}/declarations
POST /transactions/{id}/declarations
POST /transactions/{id}/declarations/{declaration_id}/confirm
POST /transactions/{id}/declarations/{declaration_id}/review
POST /transactions/{id}/dispute
POST /transactions/{id}/cancel
GET /transactions/{id}/timeline

Lawyers
GET /lawyers
GET /lawyers/{id}
GET /lawyers/{id}/reviews
POST /lawyers/{id}/hire
GET /lawyers/pending
POST /lawyers/verify/{document_id}
POST /lawyers/reject/{document_id}
POST /lawyers/review/{transaction_id}

Notaries
GET /notaries
GET /notaries/{id}
POST /notaries/{id}/hire

Services
GET /services/catalog
GET /services/orders
POST /services/orders

Messaging
GET /messaging/conversations
POST /messaging/conversations
GET /messaging/conversations/{id}/messages
POST /messaging/conversations/{id}/messages
PUT /messaging/messages/{id}
DELETE /messaging/messages/{id}
POST /messaging/conversations/{id}/read
POST /messaging/conversations/{id}/archive

Payments
GET /payments/methods
POST /payments/methods
DELETE /payments/methods/{id}
GET /payments/history
POST /payments/withdraw

Subscriptions
GET /subscriptions/plans
POST /subscriptions
GET /subscriptions/current
PUT /subscriptions/cancel
PUT /subscriptions/upgrade

Disputes
GET /disputes
GET /disputes/{id}
POST /disputes
GET /disputes/{id}/messages
POST /disputes/{id}/messages

Currencies
GET /currencies
GET /currencies/rates
GET /currencies/convert

Analytics
POST /analytics/property-view
POST /analytics/search

Admin
GET /admin/properties/pending
POST /admin/properties/{id}/approve
POST /admin/properties/{id}/reject
GET /admin/kyc/pending
GET /admin/kyc/reviews
POST /admin/kyc/reviews/{id}/assign
POST /admin/kyc/reviews/{id}/resolve
GET /admin/kyc/dashboard
POST /admin/kyc/{id}/approve
POST /admin/kyc/{id}/reject
POST /admin/escrow/{id}/approve
GET /admin/escrow/{id}/approvals
GET /admin/escrow/reconciliation
GET /admin/escrow/reconciliation/dashboard
GET /admin/fraud/events
GET /admin/fraud/events/dashboard

Webhooks
POST /webhooks/kyc
POST /webhooks/email
POST /webhooks/sms

## Implemented Production Baseline

- KYC submission pipeline with encrypted storage and background verification
  jobs
- document storage pipeline with AES-GCM encryption and structured metadata
- escrow ledger automation for deposits, holds, releases, and refunds
- external settlement declaration flow with counterparty confirmation and
  lawyer/admin review
- property admission lanes for low-risk sale inventory
- notary-led sale closing stages
- service catalog and service-order workflows for monetization
- role task feeds for buyers, sellers, lawyers, notaries, and admins
- notification outbox for email and SMS with background dispatch jobs
- provider failover for KYC, OCR, email, SMS, and FX services
- CDN-aware signed asset URL governance with transformation manifests for
  watermarking and redaction policy
- rate limiting and login abuse protection for auth endpoints with Redis-backed
  scaling support
- background job workers for verification, notification delivery, and retention
  cleanup
- background job workers for dispute escalation and AML settlement scanning
- admin endpoints for property, KYC, reconciliation, and fraud moderation
- analytics endpoints for property views and search tracking
- Cameroon administrative validation for phone, location, and payout-critical
  data
- full-text property search ranking and geo-oriented indexing maturity
- currency conversion API support with direct, inverse, and XAF-bridge paths

## Production Hardening Added

- secondary KYC and OCR failover support with OCR-informed KYC risk scoring
- additional email and SMS providers with automated delivery failover
- signed URL governance for CDN and object-storage style asset delivery
- automatic watermark and redaction policy manifests at document ingest
- full-text and geo-oriented database indexing for property discovery
- automated dispute escalation workflows in the background job runner
- AML risk scans for large cash, off-platform, and structuring-like settlement
  patterns

## Summary

The current system is aligned around legal integrity, transaction safety, and a
credible operating model for Cameroon. The documentation, backend behavior, and
database structure now reflect the same rule set.

# Database

PostgreSQL is the system of record for Real Estate Secure. The schema is built
for Cameroon-specific real estate operations, escrow governance, legal review,
and production auditability.

## Scope

The database covers:

- user identity, roles, KYC, and profile preferences
- property listings, locations, documents, and verification
- transactions, escrow balances, ledger entries, disputes, and invoices
- lawyer reviews, notification outbox, jobs, analytics, and compliance data
- Cameroon administrative reference data and off-platform settlement controls

## Migration Order

Run migrations in lexical order:

1. `0001_init.sql`
2. `0002_ops_and_jobs.sql`
3. `0003_security_hardening.sql`
4. `0004_escrow_governance.sql`
5. `0005_double_entry_ledger.sql`
6. `0006_idempotency_and_fraud.sql`
7. `0007_idempotency_payload_hash.sql`
8. `0008_kyc_review_queue.sql`
9. `0009_legal_compliance.sql`
10. `0010_exchange_rates_provider.sql`
11. `0011_remove_land_titles_and_surveyors.sql`
12. `0012_cameroon_compliance_and_external_transactions.sql`
13. `0013_cameroon_sale_compliance_and_revenue.sql`
14. `0014_low_risk_marketplace_and_closing.sql`
15. `0015_offline_legal_workflows.sql`

## Key Production Tables

Core platform:

- `users`, `user_roles`, `user_addresses`
- `identity_documents`, `business_verifications`, `biometric_registrations`
- `properties`, `property_locations`, `property_documents`, `property_images`
- `transactions`, `escrow_accounts`, `escrow_transactions`, `invoices`
- `disputes`, `dispute_messages`, `audit_logs`, `login_attempts`

Operations and controls:

- `job_queue`, `notification_outbox`
- `ledger_entry_groups`, `ledger_entries`
- `escrow_release_approvals`, `escrow_reconciliation_reports`
- `fraud_events`, `kyc_review_tasks`
- `transaction_documents`, `transaction_legal_reviews`

Cameroon compliance and external settlement:

- `cameroon_regions`, `cameroon_departments`
- `user_preferences`
- `payout_requests`
- `transaction_settlement_declarations`
- `transaction_settlement_confirmations`
- `notary_profiles`
- `platform_service_catalog`
- `service_orders`
- `transaction_offline_steps`
- `transaction_legal_cases`
- low-risk sale inventory admission fields on `properties`
- explicit closing-stage evidence fields on `transactions`

## Cameroon-Specific Rules

The backend now treats Cameroon as the authoritative operating geography:

- primary user phones are normalized to Cameroon format
- mobile money numbers must be Cameroon mobile numbers
- property and user addresses are validated against Cameroon region and
  department reference data
- property coordinates are checked against Cameroon geographic bounds
- transactional currency support is explicit, with `XAF` as the default
  accounting currency

`0012_cameroon_compliance_and_external_transactions.sql` seeds the region and
department reference tables used by the backend validation layer.

`0013_cameroon_sale_compliance_and_revenue.sql` adds Cameroon sale-compliance
state, verified notary support, and a non-transaction-fee service catalog for
monetization.

`0014_low_risk_marketplace_and_closing.sql` adds the government-light
marketplace admission model for sale inventory, explicit notary-led closing
stages, and additional document types for certificate-of-property, urbanism,
accessibility, municipal, registration, mutation, and updated-title evidence.

`0015_offline_legal_workflows.sql` adds the assisted offline and court-linked
workflow layer:

- automation freeze state on `transactions`
- old-title, court-linked, and ministry-filing risk fields on `properties`
- original-seen and certified-copy evidence metadata on property and
  transaction documents
- `transaction_offline_steps` for physical notary, municipal, tax, MINDCAF,
  court, justice-execution, commission, and cadastral follow-up
- `transaction_legal_cases` for administrative appeals, litigation, foreign
  authorization, succession, judgment-enforcement, domain national, and
  old-title regularization workflows

## Off-Platform Transaction Governance

Some deals will partially or fully settle outside platform escrow. The schema
does not ignore that reality; it records and controls it.

New flow tables:

- `transaction_settlement_declarations`
  Stores declared off-platform or hybrid settlement events, payment channels,
  references, evidence, and review status.
- `transaction_settlement_confirmations`
  Captures counterparty confirmation or rejection of a declared settlement.
- `transaction_legal_reviews`
  Stores formal lawyer decisions and notes for transaction review.

These tables let the platform:

- capture proof when buyers and sellers use cash, bank transfer, notary, or
  mobile money outside escrow
- require confirmation and legal review before treating external settlement as
  trusted
- preserve evidence and auditability for disputes and compliance reviews

## Offline and Court-Linked Governance

The platform now treats some Cameroon legal steps as explicitly physical and
office-based.

`transaction_offline_steps` stores operational follow-up for:

- notary office appointments
- municipal certificate collection
- tax registration and stamped receipt capture
- MINDCAF or land-registry filing
- court or clerk follow-up
- execution-of-judgment follow-up
- commission visits
- cadastral validation and old-title regularization

`transaction_legal_cases` stores assisted legal workflow state for:

- administrative appeal
- administrative litigation
- justice execution
- succession case handling
- judgment-enforcement handling
- domain national allocation
- old-title regularization
- foreign-party authorization

These tables support:

- `automation_frozen` transactions with a stored freeze reason
- tracking expected office, filing date, next follow-up date, and delay reason
- preserving certified or original-seen document evidence
- moving risky files through assisted handling instead of pretending they are
  simple digital closings

## Cameroon Sale Compliance and Revenue Model

The production schema now reflects the actual Cameroon sale path more closely:

- sale transactions can carry explicit legal case type and compliance metadata
- notary assignment is stored independently from lawyer assignment
- sale inventory can be classified into `government_light`, `assisted_only`,
  or `blocked` risk lanes before marketplace activation
- sale closing is separated from payment flow with explicit stages:
  `commercially_closed`, `notarial_deed_signed`, `mutation_filed`,
  `title_transfer_confirmed`
- foreign-party involvement and MINDCAF visa requirements can be recorded
- physical and court-linked workflows can be modeled without pretending the
  platform itself performs the state process
- platform monetization is moved away from sale-percentage charging and toward:
  subscriptions, featured boosts, verification bundles, document vault
  subscriptions, foreign-buyer packs, professional lead matching, and developer
  workspace products

The `platform_fee_*` and `transaction_fee_percentage` columns remain for
backward compatibility, but the production defaults are now zero and new
commercial products are modeled in `platform_service_catalog` and
`service_orders`.

## Recommended Execution

Use a real migration tool in deployment:

- Flyway
- Sqitch
- Liquibase
- a controlled CI migration runner

For local development, the repo scripts under [`scripts/`](../scripts) can be
used with Docker Compose from [`infra/`](../infra).

## Seeds

Reference seeds live under `seeds/`:

- currencies
- subscription plans
- exchange rates

Keep seed data idempotent so repeated environment bootstrap is safe.

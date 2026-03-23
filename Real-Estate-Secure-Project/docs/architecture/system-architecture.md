# Real Estate Secure - System Architecture

## Executive Summary

Real Estate Secure is a Cameroon-focused verified marketplace, escrow ledger,
evidence vault, and workflow platform. The system is designed to reduce land
fraud without positioning the platform as the land-transfer agent. The parties,
and especially the notary on sale files, handle the government-facing
formalities while the platform coordinates evidence, funds, tasks, and audit
history.

## Operating Boundary

The production system follows these architecture rules:

- the platform does not submit title mutation files to government systems
- the platform stores and verifies evidence of compliant closing
- notaries lead standard sale closings
- lawyers are assigned selectively based on risk profile
- only government-light sale inventory can enter the standard marketplace
- platform revenue comes from subscriptions and paid services, not sale-value
  transaction fees

## Architecture Overview

```
Clients (Flutter, Web, Admin)
        |
        v
   Dart API Gateway (Shelf)
        |
        +--> Auth, Users, Roles, KYC
        +--> Properties, Documents, Admission, Search
        +--> Transactions, Escrow, External Settlements
        +--> Lawyers, Notaries, Compliance
        +--> Messaging, Notifications
        +--> Services, Subscriptions, Payments
        +--> Analytics, Fraud, Admin
        |
        v
PostgreSQL + Object Storage + Queue + Cache + Observability
        |
        v
Background Workers (verification, indexing, notifications, retention)
```

## Core Services

- **Identity and access**
  Registration, MFA, KYC, role management, and primary-role switching.
- **Property marketplace**
  Listings, location validation, media, sale admission lanes, and search.
- **Document and evidence vault**
  Encrypted property and transaction evidence with verification history and
  access controls.
- **Transactions and escrow**
  Escrow balances, holds, refunds, releases, external settlement declarations,
  and immutable ledger records.
- **Legal and closing coordination**
  Lawyer review, notary assignment, closing-stage progression, and dispute
  evidence.
- **Assisted legal workflow**
  Offline-step tracking, legal-case tracking, automation freeze control, and
  physical-evidence metadata for court-linked or ministry-dependent files.
- **Paid services**
  Verification bundles, document vault products, promoted listings, compliance
  packs, and service orders.
- **Admin, analytics, and fraud**
  Moderation, reconciliation, KYC review, fraud dashboards, and compliance
  exports.

## Role Model

The effective production roles are:

- buyer
- seller
- lawyer
- notary
- admin

Legacy roles can still exist in the schema, but the production sale path is
optimized around buyer, seller, lawyer, notary, and admin. Users can hold
multiple roles and choose a primary role for the UI.

## Sale Admission Model

Sale inventory is evaluated before it reaches the marketplace.

- `government_light`
  Eligible for the normal marketplace lane.
- `assisted_only`
  Kept out of the low-risk lane and routed to higher-touch handling.
- `blocked`
  Rejected from platform sale flow.

The low-risk lane expects:

- already titled private property
- recent certificate of property
- urbanism and accessibility certificates
- clear seller identity
- no declared dispute or encumbrance
- no foreign-party requirement

Files such as untitled/customary land, domain national allocations, succession,
judgment-driven transfers, foreign-party deals, and dispute-heavy files are
blocked or diverted out of ordinary marketplace activation.

For assisted files, the backend now creates explicit workflow records instead
of keeping risk only in narrative notes:

- `transaction_offline_steps`
  For notary-office, municipal, tax, MINDCAF, court, commission, and
  cadastral follow-up.
- `transaction_legal_cases`
  For administrative appeals, litigation, foreign authorization, succession,
  judgment-enforcement, domain national, justice execution, and old-title
  regularization handling.

## Closing Model

Sale transactions separate commercial progress from title-transfer progress.

- `pre_closing`
- `commercially_closed`
- `notarial_deed_signed`
- `mutation_filed`
- `title_transfer_confirmed`

Release and completion are evidence-based. The system stores:

- notary deed evidence
- registration receipt evidence
- title mutation or updated title evidence
- payment evidence for external or hybrid settlements

The platform records compliance evidence; it does not represent that a transfer
has occurred merely because money moved.

If court, ministry, or commission blockers remain open, the transaction can be
marked `automation_frozen` with a stored reason. That prevents the platform
from pretending a risky file is flowing like a clean marketplace sale.

## Data Layer

PostgreSQL is the primary system of record for users, roles, KYC state,
properties, admission state, transactions, service orders, disputes, audit
logs, and compliance history.

Key guarantees:

- strict foreign keys, checks, and enums for core workflow state
- idempotency support on money-moving and provider-sensitive actions
- escrow ledger integrity and reconciliation support
- tamper-evident audit history for state changes

Object storage holds encrypted documents and media, while cache and queue
layers support rate limiting, sessions, indexing, notifications, and scheduled
jobs.

## Integrations and Pipelines

- **KYC/OCR**
  Sumsub-backed verification with provider-case review and webhook reconciliation.
- **Notifications**
  SendGrid email and Africa's Talking SMS with webhook processing.
- **FX rates**
  Scheduled provider-backed refresh with XAF as the accounting base.
- **Maps and location**
  Cameroon-specific region, department, and coordinate validation before write
  acceptance.
- **Workers**
  Verification, indexing, notification, retention, and reconciliation jobs.

## Security and Compliance

- MFA for high-risk and privileged actions
- rate limiting, lockouts, and abuse controls on auth flows
- encrypted document storage and signed retrieval
- audit trails on user, property, transaction, and admin workflows
- four-eyes approval for high-value escrow releases
- admin IP allowlisting in production
- retention and legal-hold support for regulated evidence

## Monetization Architecture

The platform no longer relies on sale-value transaction fees. Monetization is
handled by catalog-backed services and subscriptions, including:

- subscriptions
- verification bundles
- document vault access
- featured listings
- premium advertising
- developer workspace access
- lawyer and notary matching
- foreign-buyer compliance packs

## Operations and Observability

- structured logs with request IDs and trace context
- readiness and health checks
- reconciliation and fraud dashboards
- webhook verification and replay protection
- backup, retention, and recovery procedures
- deployment and incident guidance in
  `docs/architecture/deployment-runbook.md`

## Technology Stack

- **Backend**
  Dart with Shelf and PostgreSQL access.
- **Database**
  PostgreSQL with typed enums, strict constraints, and audit-friendly schema.
- **Clients**
  Flutter-first mobile plus web and admin clients.
- **Async**
  Redis Streams or RabbitMQ for worker jobs.
- **Storage**
  S3-compatible object storage with signed delivery.
- **Search**
  Postgres full-text baseline with optional Elasticsearch.

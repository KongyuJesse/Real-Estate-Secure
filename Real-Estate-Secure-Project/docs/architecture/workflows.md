# Real Estate Secure - System Workflows

## Overview

These workflows describe the current production operating model for Real Estate
Secure. The platform is a verified marketplace, escrow and evidence system, and
workflow coordinator. It does not act as the government-facing land transfer
agent.

## Role Goals

**Buyer**
1. Discover only eligible marketplace listings.
2. Review evidence and decide whether to use escrow, hybrid, or declared
   off-platform settlement.
3. Complete inspection and closing steps.
4. Receive auditable transaction history and evidence.

**Seller**
1. List only admissible inventory.
2. Upload and maintain the documentary file.
3. Coordinate buyer, notary, and lawyer tasks where applicable.
4. Receive release only after compliant closing evidence is present.

**Lawyer**
1. Review only files that require or request legal review.
2. Validate complex or risky evidence sets.
3. Review disputed or external settlement cases.
4. Approve or block legal release decisions on relevant files.

**Notary**
1. Lead sale closing on standard property sales.
2. Confirm deed execution and registration evidence.
3. Advance closing stages through documentary proof.
4. Support mutation and updated title evidence capture.

**Admin**
1. Moderate listings and KYC.
2. Monitor reconciliation, fraud, and service operations.
3. Provide four-eyes approvals for high-value release.
4. Handle compliance exceptions and backlog management.

## User Onboarding Flow

**Steps**
1. Register with email, phone, password, and legal-consent timestamps.
2. Backend validates Cameroon phone format and basic identity data.
3. Send email and phone verification messages.
4. Complete KYC upload.
5. Encrypt and store identity files and metadata.
6. Run provider-backed KYC review and risk scoring.
7. Mark user verified, rejected, or pending manual review.
8. Allow role activation and task feed access.

**Controls**
- auth rate limiting and lockouts
- audit logs for registration and verification events
- MFA for privileged or high-risk flows

## Role Upgrade and Role Switching

**Steps**
1. User requests a self-service role such as buyer or seller.
2. System checks current KYC state.
3. If KYC is incomplete, role remains pending with metadata explaining why.
4. User can list their roles and set a primary role for the dashboard.
5. New role set is returned to the client for token refresh and UI update.

**Controls**
- role changes are audited
- non-self-service roles remain approval controlled

## Property Listing and Admission Flow

**Steps**
1. Seller creates a listing with type, listing mode, price, and Cameroon
   location.
2. Backend validates region, department, city, and coordinates.
3. For sale listings, seller declares inventory type and known risk flags.
4. Seller uploads property documents into the evidence vault.
5. The admission engine evaluates the file.
6. Listing is classified into one of three lanes:
   `government_light`, `assisted_only`, or `blocked`.
7. `government_light` files can continue toward verification and publication.
8. `assisted_only` or `blocked` files are kept out of the ordinary marketplace.
9. Admin and legal review can approve or reject the listing after evidence
   checks.
10. Search indexing runs only after the file is eligible and verified.

**Minimum low-risk sale lane**
- titled private property
- recent certificate of property
- urbanism certificate
- accessibility certificate
- clear seller identity
- no known dispute or encumbrance
- no foreign-party involvement

**Blocked or assisted examples**
- untitled/customary land
- domain national allocation
- succession estate sales
- judgment-enforcement transfers
- foreign-party files
- disputed or encumbered property

## Standard Sale Transaction Flow

**Steps**
1. Buyer selects an eligible sale listing.
2. Buyer initiates a transaction and chooses settlement mode:
   `platform_escrow`, `hybrid`, or `off_platform`.
3. The legal requirement profile is computed from the file and transaction
   flags.
4. Assisted files seed offline steps and legal-case records immediately.
5. Buyer or seller assigns a notary for sale closing.
6. Lawyer is assigned only if the file requires or requests legal review.
7. Funds move into escrow, or external settlement is declared and reviewed.
8. Buyer completes inspection or raises a dispute.
9. Notary advances the closing evidence stages when automation is not frozen.
10. Lawyer approves legal release only where required by the case profile.
11. High-value release may require secondary admin approval.
12. Release, refund, or continued hold is recorded in the ledger.
13. Property and transaction records are updated with the final evidence state.

**Controls**
- sale initiation is blocked for non-eligible sale listings
- `assisted_only` files can open guided transactions, but court or ministry
  blockers freeze normal automation
- timeline and ledger entries remain auditable
- money movement does not imply title transfer completion

## Notary-Led Closing Workflow

**Stages**
1. `commercially_closed`
   Buyer and seller have reached the commercial close point through escrow or a
   sufficiently confirmed external settlement.
2. `notarial_deed_signed`
   Notary deed evidence is attached and closing file is ready.
3. `mutation_filed`
   Registration or title-mutation receipt evidence is attached.
4. `title_transfer_confirmed`
   Updated title evidence or final mutation proof is attached.

**Controls**
- only notary or admin can advance sale closing stages
- stage progression is forward-only
- evidence requirements are validated before stage change
- sale release is blocked until title-transfer confirmation exists
- closing-stage automation is blocked while unresolved assisted legal cases or
  offline blockers keep the transaction frozen

## Assisted Offline and Court-Linked Workflow

**When this workflow is used**
- foreign-party sale files
- administrative appeals or administrative litigation
- justice execution and judgment-enforcement cases
- domain national procedures
- old-title regularization
- court-linked property files
- ministry-dependent filings that cannot be treated as standard marketplace
  automation

**Steps**
1. Transaction is marked for assisted handling.
2. Backend stores `assisted_lane_reason`, `offline_workflow_required`, and
   `automation_frozen` state where applicable.
3. Offline steps are created for notary-office, municipal, tax, MINDCAF,
   court, commission, or cadastral follow-up.
4. Legal cases are created for the relevant administrative, court, or foreign
   authorization workflow.
5. Parties and professionals upload stamped or certified evidence.
6. Next follow-up date, expected office, delay reason, and physical-status
   state are updated over time.
7. Once freeze-causing blockers are resolved, automation can resume and the
   notary-led closing flow continues.

**Evidence examples**
- stamped filing receipts
- hearing notices
- clerk-issued documents
- certified judgment copies
- certificate of non-appeal
- ministerial non-objection
- site-visit reports
- commission minutes
- cadastral signed plans
- original-seen and certified-copy attestations

## External or Hybrid Settlement Workflow

**Steps**
1. Buyer or seller declares an off-platform or hybrid settlement event.
2. Payment channel, amount, timestamp, and optional reference are captured.
3. Evidence can be attached as transaction documents.
4. Counterparty confirms or rejects the declaration.
5. Lawyer or admin reviews and confirms, rejects, or flags the declaration.
6. Confirmed external settlement can move the file to the commercial close
   stage without pretending that title transfer is complete.

**Controls**
- every declaration is tied to a transaction
- review history remains auditable
- risky external-settlement files can require lawyer review

## Lawyer Review Workflow

Lawyer review is selective, not universal.

**Lawyer is typically required for**
- foreign-party transactions
- succession or estate sales
- corporate-party files
- power-of-attorney use
- encumbered or disputed files
- judgment-driven files
- off-platform or hybrid settlement cases when policy requires review

**Steps**
1. Lawyer opens pending review work.
2. Lawyer evaluates the document set and transaction context.
3. Decision is recorded with notes and structured reasons.
4. Transaction or document state is updated.
5. Parties are notified of the result.

## Escrow, Hold, Release, and Refund Workflow

**Steps**
1. Create or locate the escrow record for the transaction.
2. Record deposits with idempotency protection.
3. Hold funds where required.
4. Verify release prerequisites:
   legal requirement, four-eyes threshold, dispute state, and closing stage.
5. Release or refund with ledger updates.
6. Notify parties and persist audit history.

**Controls**
- high-value release can require admin approval
- sale release depends on title-transfer confirmation, not just money deposit
- reconciliation checks compare balances with ledger sums

## Dispute Resolution Workflow

**Steps**
1. Buyer or seller opens a dispute.
2. Release is frozen.
3. Parties exchange evidence and messages.
4. Lawyer or admin mediates and records a decision.
5. Transaction is resolved through release, hold, refund, or cancellation.

**Controls**
- evidence remains attached to the dispute trail
- dispute state is preserved in the transaction timeline

## Service Order Workflow

**Steps**
1. User browses the service catalog.
2. User places an order for an explicit product.
3. Payment and fulfillment state are tracked independently from the property
   sale amount.
4. Admin can dispatch or monitor service backlog.

**Examples**
- verification bundle
- document vault
- promoted listing
- premium advertising
- developer workspace
- lawyer or notary matching
- foreign-buyer compliance pack

## Notification and Webhook Workflow

**Steps**
1. Backend writes an outbox event.
2. Worker dispatches through email or SMS provider.
3. Provider webhook returns delivery state.
4. Signature verification and replay protection are applied.
5. Delivery status is updated for audit and retry handling.

## Analytics and Retention Workflow

**Steps**
1. Capture property-view and search events.
2. Store analytics with session and filter context.
3. Run fraud or bot scoring where configured.
4. Archive or anonymize data according to retention policy.

## Role Task Feed Workflow

Each role receives next-step work instead of passive records.

- buyers receive tasks such as fund escrow, declare settlement, inspect, or
  follow title transfer and assisted-lane blockers
- sellers receive tasks such as complete admission documents or coordinate
  notary evidence
- lawyers receive pending document review, settlement review, legal-case, and
  offline-step oversight tasks
- notaries receive deed, mutation, title confirmation, and physical file
  coordination tasks
- admins receive moderation, KYC, reconciliation, service-order, frozen
  assisted-transaction, and admin-oversight legal-case tasks

# Real Estate Secure - Deployment and Runbook

## Purpose

This document provides production deployment checks and incident runbooks for
Real Estate Secure.

## Pre-Deployment Checklist

1. Confirm secrets are stored in the approved secrets manager.
2. Verify `SECRETS_LAST_ROTATED_AT` is within rotation policy.
3. Confirm admin IP allowlist is configured for production.
4. Run database migrations in staging first, including the sale admission and
   closing-stage migrations.
5. Validate readiness endpoint returns `200` in staging.
6. Verify provider webhooks are reachable and signatures validate.
7. Confirm KYC callbacks match `KYC_PROVIDER_CALLBACK_URL`.
8. Ensure MFA policy is active for admin and legal-sensitive actions.
9. Confirm service catalog seed data is present for production monetization.
10. Confirm backups are enabled and recent.

## Deployment Steps

1. Freeze schema migrations and generate the migration plan.
2. Apply migrations in production with transaction logging enabled.
3. Deploy API containers with rolling update or canary strategy.
4. Run post-deploy smoke tests on auth, KYC, property admission, service
   catalog, and transaction closing-stage endpoints.
5. Monitor error rates, latency, and job queue depth.

## Post-Deployment Checklist

1. Validate `/ready` and `/health` endpoints.
2. Verify outbound email and SMS provider responses.
3. Confirm escrow reconciliation job executed successfully.
4. Review admin dashboards for pending KYC reviews, escrow approvals, fraud
   events, and service-order backlog.
5. Confirm audit logs are being written for auth, property admission, and
   transaction workflows.

## Rollback Strategy

1. Stop write traffic if data integrity is at risk.
2. Roll back API containers to the last stable image.
3. If migrations changed schema, use backward-compatible rollback scripts.
4. Re-run reconciliation and validate escrow balances.

## Incident Runbooks

### KYC Provider Outage

1. Verify circuit breaker status and provider health.
2. Disable automatic KYC submission and queue pending requests.
3. Notify support and update the status page.
4. Resume processing after provider recovery.

### Escrow Mismatch Detected

1. Check the latest reconciliation report for affected accounts.
2. Freeze escrow release for impacted transactions.
3. Validate ledger entries against provider settlement.
4. Correct balances and document the resolution in audit logs.

### Sale Closing Stage Blocked

1. Check the transaction compliance payload and current `closing_stage`.
2. Verify notary assignment is present.
3. Verify required evidence documents were uploaded:
   notary deed, registration receipt, mutation or updated title evidence.
4. If the file is actually assisted-only or blocked, stop marketplace
   progression and notify operations.
5. Record the intervention in audit logs.

### Property Admission Drift

1. Check the current admission profile for the property.
2. Verify whether required sale evidence is missing or expired.
3. Remove or hold publication for files that no longer qualify as
   `government_light`.
4. Notify seller and the admin review queue.

### SMS or Email Delivery Failure

1. Inspect webhook logs and provider error codes.
2. Check circuit breaker state and retry queue.
3. Switch to a backup provider if configured.
4. Notify support teams of delivery delays.

### Unauthorized Admin Access Attempt

1. Verify IP allowlist configuration and access logs.
2. Rotate admin credentials and force MFA reset.
3. Review audit logs for impacted actions.

## Production Checklist (Quarterly)

1. Rotate all provider keys and secrets.
2. Review and update incident runbooks.
3. Execute a disaster recovery drill.
4. Review data retention and legal-hold policies.
5. Audit admin access, approval logs, and service-order operations.

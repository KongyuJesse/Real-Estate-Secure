# Mobile Trust and Payments Plan

## KYC direction

The mobile KYC stack is now **Sumsub-first**.

We are not shipping:

- a fully custom upload-only KYC flow as the main path
- a fully provider-branded app experience that replaces the Real Estate Secure trust shell

We are shipping a hybrid model:

1. Real Estate Secure owns the shell.
   The app keeps consent, onboarding, account context, trust education, retry handling, and verification status.
2. Sumsub owns the high-risk capture moments.
   The SDK handles live document capture, selfie capture, liveness, and provider-grade anti-fraud capture UX.
3. The backend owns final trust state.
   The backend issues Sumsub SDK access tokens, stores provider cases, verifies webhooks, and decides when the platform account becomes verified.

## What this means in the app

- The KYC submission screen stays on-brand and explains the flow.
- The primary action launches the Sumsub SDK.
- Email and phone verification run through one shared Sumsub applicant-actions level.
- Verification history should show provider records only.
- Security Center and profile surfaces must reflect real KYC state, not only contact verification.

## Sumsub implementation contract

### Backend

- Issue SDK access tokens from the backend.
- Keep Sumsub app token and secret key server-side only.
- Reconcile applicant state through webhooks and backend lookups.
- Store provider cases and raw provider events for audit and replay.
- Never mark a user verified from mobile callback data alone.

### Mobile

- Launch Sumsub through the Flutter plugin.
- Support token refresh from the backend while the SDK is open.
- Use Sumsub applicant actions for email and phone confirmation.
- Keep provider capture themed to match the app where supported.
- Return users to the Real Estate Secure trust surfaces after capture so status stays coherent.

## Why Sumsub was chosen

- Official Flutter plugin support.
- Access-token based mobile launch model that fits a backend-issued session.
- Token refresh support for long-running verification sessions.
- Theme and localization support that preserves the Real Estate Secure design shell.
- A clean separation between capture UX in the SDK and final trust state in our backend.

## Payment orchestration model

Payments follow the same ownership split:

1. Real Estate Secure owns plan selection and entitlement UX.
2. Notch Pay owns hosted payment authorization.
3. The backend owns checkout initialization, webhook reconciliation, and subscription activation.

## Implemented platform direction

- Sumsub is the primary KYC vendor.
- Sumsub is the only active KYC and contact verification path in the mobile product.
- Notch Pay is the primary Cameroon payment rail in this repo.
- The app UI remains the trust shell for KYC and subscriptions.

## Next production steps

1. Apply the Sumsub provider-case migration in production.
2. Configure Sumsub app token, secret key, webhook secret, and level name on the backend.
3. Register webhook delivery and replay monitoring for provider events.
4. Finish provider-result moderation and operations tooling for support/admin teams.
5. Add seller payout operations after collection flows are stable.

## Official references

- Sumsub Flutter plugin
  https://docs.sumsub.com/docs/flutter-plugin
- Sumsub framework plugins
  https://docs.sumsub.com/docs/framework-plugins
- Sumsub plugin customization
  https://docs.sumsub.com/docs/plugins-customization
- Sumsub API authentication
  https://docs.sumsub.com/reference/authentication
- Sumsub applicant management
  https://docs.sumsub.com/reference/get-applicant-data-by-external-user-id
- Notch Pay authentication
  https://developer.notchpay.co/api-reference/authentication
- Notch Pay payments API
  https://developer.notchpay.co/api-reference/payments
- Notch Pay webhook guidance
  https://developer.notchpay.co/sync/integration

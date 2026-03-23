# Real-Estate-Secure

Monorepo for the Real-Estate-Secure platform. The mobile Flutter app lives under `mobile_app/`, while backend, database, docs, and infrastructure live in their own top-level folders.

## Structure
- `mobile_app/` Flutter mobile application (Android project is under `mobile_app/android`).
- `backend/` Backend API services and supporting libraries.
- `database/` PostgreSQL migrations, seed data, and schema docs.
- `docs/` Architecture notes and API references.
- `infra/` Infrastructure and deployment assets.
- `scripts/` Automation and developer tooling.
- `shared/` Shared contracts and utilities.

## Stack

- Dart backend (Shelf + postgres client)
- PostgreSQL for relational data and compliance logs
- Flutter mobile app

## Idempotency Conflicts (409)

Escrow operations support idempotency keys. If the same key is reused with a
different payload, the API returns `409`:

```json
{
  "status": "error",
  "error": {
    "message": "Idempotency key already used with different payload.",
    "code": "IDEMPOTENCY_CONFLICT"
  },
  "request_id": "req_01HZXPKD7R2Y"
}
```

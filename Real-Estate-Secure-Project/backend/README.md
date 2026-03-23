# Real Estate Secure Backend

This backend now runs on `Node.js + Express` and connects directly to the existing PostgreSQL schema.

## Stack

- Node.js 22+
- Express 4
- PostgreSQL via `pg`
- JWT auth with `jsonwebtoken`
- Password hashing with `bcryptjs`

## Scripts

- `npm install`
- `npm run migrate`
- `npm run migrate:seed`
- `npm start`
- `npm run dev`
- `npm run check`
- `npm test`

## Environment

The backend reads from `.env` and `.env.example`.

Minimum local variables:

- `DATABASE_URL`
- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `PORT`
- `AUTO_RUN_MIGRATIONS`

Recommended production security variables now include:

- `AUTH_MAX_FAILED_ATTEMPTS`, `AUTH_LOCKOUT_MINUTES`
- `AUTH_LOGIN_RATE_LIMIT_WINDOW_MS`, `AUTH_LOGIN_RATE_LIMIT_MAX`
- `AUTH_PASSWORD_RESET_RATE_LIMIT_WINDOW_MS`, `AUTH_PASSWORD_RESET_RATE_LIMIT_MAX`
- `AUTH_REFRESH_RATE_LIMIT_WINDOW_MS`, `AUTH_REFRESH_RATE_LIMIT_MAX`
- `MFA_TOTP_ISSUER`, `MFA_TOTP_DIGITS`, `MFA_TOTP_STEP_SEC`, `MFA_TOTP_WINDOW`
- `MALWARE_SCAN_MODE`, `MALWARE_SCAN_HOST`, `MALWARE_SCAN_PORT`, `MALWARE_SCAN_TIMEOUT_MS`, `MALWARE_SCAN_FAIL_CLOSED`

## Run

```powershell
cd backend
npm install
npm run migrate
npm start
```

If `npm start` reports that port `8080` is already in use, one backend instance is already running. In that case:

- keep using the existing server on `http://localhost:8080`
- or free the port on Windows:

```powershell
netstat -ano | findstr :8080
taskkill /PID <pid> /F
```

- or start a second instance on another port:

```powershell
$env:PORT=8081
npm start
```

If you run the backend on a non-default port for local Android testing, start Flutter with a matching hidden build-time override:

```powershell
flutter run --dart-define=RES_API_BASE_URL=http://10.0.2.2:8081/v1
```

If the existing process on `8080` is already this backend, `npm start` now exits cleanly after telling you the backend is already running.

Windows helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-dev-server.ps1
```

## API shape

The Express backend preserves the current route families:

- `/health`, `/ready`
- `/auth/*`
- `/users/*`
- `/properties/*`
- `/transactions/*`
- `/notifications/*`
- `/lawyers/*`
- `/notaries/*`
- `/conversations/*`, `/messages/*`
- `/payments/*`
- `/subscriptions/*`
- `/currencies/*`
- `/services/*`
- `/disputes/*`
- `/analytics/*`
- `/admin/*`
- `/webhooks/*`

Responses use:

```json
{
  "status": "success",
  "data": {},
  "request_id": "..."
}
```

## Security hardening included

The backend now includes production-focused protections for the mobile channel:

- role canonicalization across backend/mobile payloads
- login, refresh, and password-reset route throttling
- account lockout after repeated failed sign-ins
- TOTP enrollment and verification endpoints for two-factor authentication
- biometric credential registration and verification scaffolding
- Cameroon-specific phone normalization and property location validation
- property admission checks for low-risk sale lanes
- evidence-gated closing state transitions for transaction completion
- pluggable malware scanning with `heuristic`, `clamav`, or `off` modes

Run `npm test` to execute backend unit tests for the hardened validation and MFA helpers.

## Local Auth and Mobile Pairing

- The backend listens on `http://localhost:8080` by default.
- The Flutter Android emulator reaches this backend through `http://10.0.2.2:8080/v1`.
- Startup now tracks applied SQL files in `schema_migrations`, so local boots no longer replay every migration file on each run.

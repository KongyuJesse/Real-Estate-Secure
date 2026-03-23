const crypto = require('crypto');
const express = require('express');
const { z } = require('zod');

const { query, withTransaction } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const {
  badRequest,
  conflict,
  forbidden,
  notFound,
  tooManyRequests,
  unauthorized,
} = require('../lib/errors');
const {
  canonicalizeRole,
  canonicalizeRoles,
  hasRestrictedMobileRole,
  isAllowedMobileRegistrationRole,
  normalizeRole,
  resolvePrimaryMobileRole,
} = require('../lib/mobile-roles');
const {
  assertAccessSessionActive,
  hashPassword,
  verifyAccessToken,
  verifyPassword,
  issueSessionTokens,
  revokeAccessSession,
  revokeAllUserSessions,
  verifyRefreshSession,
} = require('../services/auth-service');
const {
  consumeActionToken,
  createActionToken,
  findActionTokenByToken,
  getTokenTargetValue,
  previewPayload,
} = require('../services/auth-action-service');
const { config } = require('../config');
const { requireAuth } = require('../middleware/auth');
const { createRouteRateLimiter } = require('../middleware/route-rate-limit');
const { appendOutboxEvent } = require('../services/outbox-service');
const {
  createInAppNotification,
  queueTemplatedNotification,
} = require('../services/notification-service');
const {
  buildOtpAuthUrl,
  decryptTotpSecret,
  encryptTotpSecret,
  generateTotpSecret,
  verifyTotpCode,
} = require('../services/mfa-service');
const { recordFraudEvent } = require('../services/fraud-service');
const { normalizeCameroonPhoneNumber } = require('../services/cameroon-validation-service');

const deviceSchema = z.object({
  device_id: z.string().min(3).max(128).optional(),
  device_name: z.string().min(1).max(255).optional(),
  platform: z.string().min(1).max(50).optional(),
  app_version: z.string().min(1).max(50).optional(),
});

const registerSchema = deviceSchema.extend({
  email: z.string().email(),
  password: z.string().min(8),
  phone_number: z.string().min(9),
  phone_country_code: z.string().default(config.defaultCountryCode),
  first_name: z.string().min(1),
  last_name: z.string().min(1),
  date_of_birth: z.string().min(10),
  role: z.string().optional(),
});

const loginSchema = deviceSchema.extend({
  email: z.string().email(),
  password: z.string().min(1),
  two_factor_code: z.string().min(6).max(8).optional(),
});

const refreshSchema = deviceSchema.extend({
  refresh_token: z.string().min(16),
});

const forgotPasswordSchema = z.object({
  email: z.string().email(),
});

const resetPasswordSchema = z.object({
  token: z.string().min(16),
  password: z.string().min(8),
});

const twoFactorVerifySchema = z.object({
  code: z.string().min(6).max(8),
  mfa_token: z.string().min(16).optional(),
});

const biometricRegisterSchema = z.object({
  credential_id: z.string().min(8),
  public_key: z.string().min(32),
  device_name: z.string().min(1).max(255).optional(),
  device_type: z.string().min(1).max(50).optional(),
});

const biometricVerifySchema = z.object({
  credential_id: z.string().min(8),
  challenge: z.string().min(8),
  signature: z.string().min(16),
});

const loginRateLimiter = createRouteRateLimiter({
  windowMs: config.authLoginRateLimitWindowMs,
  max: config.authLoginRateLimitMax,
  skipSuccessfulRequests: true,
  message: 'Too many sign-in attempts. Please wait before trying again.',
  keyGenerator(req) {
    const email = String(req.body?.email || '').trim().toLowerCase() || 'anonymous';
    return `auth:login:${req.ip}:${email}`;
  },
});

const refreshRateLimiter = createRouteRateLimiter({
  windowMs: config.authRefreshRateLimitWindowMs,
  max: config.authRefreshRateLimitMax,
  skipSuccessfulRequests: true,
  message: 'Too many session refresh attempts. Please wait and try again.',
  keyGenerator(req) {
    const refreshToken = String(req.body?.refresh_token || '').trim();
    return `auth:refresh:${req.ip}:${refreshToken.slice(0, 24) || 'anonymous'}`;
  },
});

const passwordResetRateLimiter = createRouteRateLimiter({
  windowMs: config.authPasswordResetRateLimitWindowMs,
  max: config.authPasswordResetRateLimitMax,
  message: 'Too many password reset requests. Please wait before trying again.',
  keyGenerator(req) {
    const email = String(req.body?.email || '').trim().toLowerCase() || 'anonymous';
    return `auth:password-reset:${req.ip}:${email}`;
  },
});

function serializeUser(row) {
  const roles = canonicalizeRoles(row.roles || []);
  const primaryRole = resolvePrimaryMobileRole(row.roles || [], row.primary_role);

  return {
    uuid: row.uuid,
    email: row.email,
    phone_number: row.phone_number,
    first_name: row.first_name,
    last_name: row.last_name,
    profile_image_url: row.profile_image_url ?? '',
    preferred_language: row.preferred_language ?? config.defaultLanguage,
    bio: row.bio ?? '',
    roles,
    primary_role: primaryRole,
    is_active: row.is_active,
    email_verified: row.email_verified === true,
    phone_verified: row.phone_verified === true,
    is_verified: row.is_verified === true,
    two_factor_enabled: row.two_factor_enabled === true,
  };
}

async function fetchUserProfileByUuid(uuid) {
  const result = await query(
    `SELECT
        u.id,
        u.uuid,
        u.email,
        u.phone_number,
        u.first_name,
        u.last_name,
        u.profile_image_url,
        u.preferred_language,
        u.bio,
        u.is_active,
        u.two_factor_enabled,
        (u.email_verified_at IS NOT NULL) AS email_verified,
        (u.phone_verified_at IS NOT NULL) AS phone_verified,
        (u.email_verified_at IS NOT NULL OR u.phone_verified_at IS NOT NULL) AS is_verified,
        COALESCE(
          array_agg(ur.role::text ORDER BY ur.is_primary DESC, ur.role)
            FILTER (WHERE ur.role IS NOT NULL),
          ARRAY[]::text[]
        ) AS roles,
        MAX(CASE WHEN ur.is_primary THEN ur.role::text END) AS primary_role
     FROM users u
     LEFT JOIN user_roles ur ON ur.user_id = u.id
     WHERE u.uuid = $1
     GROUP BY u.id`,
    [uuid],
  );
  if (!result.rows[0]) {
    throw notFound('User not found.');
  }
  return result.rows[0];
}

async function recordLoginAttempt({ email = null, userId = null, successFlag, failureReason = null, req }) {
  await query(
    `INSERT INTO login_attempts (email, user_id, ip_address, user_agent, success, failure_reason, two_factor_used)
     VALUES ($1,$2,$3,$4,$5,$6,false)`,
    [
      email,
      userId,
      req.ip ?? null,
      req.headers['user-agent'] ?? null,
      successFlag,
      failureReason,
    ],
  ).catch(() => {});
}

function buildAuthUserSelect(whereClause) {
  return `SELECT
      u.id,
      u.uuid,
      u.email,
      u.phone_number,
      u.password_hash,
      u.first_name,
      u.last_name,
      u.profile_image_url,
      u.preferred_language,
      u.bio,
      u.is_active,
      u.is_suspended,
      u.two_factor_enabled,
      u.two_factor_secret,
      u.failed_login_attempts,
      u.locked_until,
      (u.email_verified_at IS NOT NULL) AS email_verified,
      (u.phone_verified_at IS NOT NULL) AS phone_verified,
      (u.email_verified_at IS NOT NULL OR u.phone_verified_at IS NOT NULL) AS is_verified,
      COALESCE(
        array_agg(ur.role::text ORDER BY ur.is_primary DESC, ur.role)
          FILTER (WHERE ur.role IS NOT NULL),
        ARRAY[]::text[]
      ) AS roles,
      MAX(CASE WHEN ur.is_primary THEN ur.role::text END) AS primary_role
   FROM users u
   LEFT JOIN user_roles ur ON ur.user_id = u.id
   WHERE ${whereClause}
   GROUP BY u.id`;
}

async function fetchAuthUserByEmail(email) {
  const result = await query(buildAuthUserSelect('u.email = $1'), [email.toLowerCase()]);
  return result.rows[0] ?? null;
}

async function fetchAuthUserById(userId) {
  const result = await query(buildAuthUserSelect('u.id = $1'), [userId]);
  return result.rows[0] ?? null;
}

async function recordAuthAnomaly({ eventType, severity = 'medium', userId = null, req, payload = {} }) {
  await recordFraudEvent({
    eventType,
    severity,
    referenceType: userId ? 'user' : 'session',
    referenceId: userId ?? 0,
    payload: {
      request_id: req.requestId,
      ip_address: req.ip ?? null,
      user_agent: req.headers['user-agent'] ?? null,
      ...payload,
    },
  });
}

function assertAccountNotLocked(user) {
  const lockedUntil = user?.locked_until ? new Date(user.locked_until) : null;
  if (!lockedUntil || Number.isNaN(lockedUntil.getTime()) || lockedUntil.getTime() <= Date.now()) {
    return;
  }

  throw tooManyRequests(`Too many failed sign-in attempts. Try again after ${lockedUntil.toISOString()}.`);
}

async function handleFailedLogin({ user = null, email, failureReason, req }) {
  let lockedUntil = null;

  if (user?.id) {
    const nextAttempts = Number(user.failed_login_attempts ?? 0) + 1;
    const shouldLock = nextAttempts >= config.authMaxFailedAttempts;
    const existingLockMs = user.locked_until ? new Date(user.locked_until).getTime() : 0;
    lockedUntil = shouldLock
      ? new Date(Math.max(existingLockMs, Date.now()) + config.authLockoutMinutes * 60 * 1000)
      : null;

    await query(
      `UPDATE users
       SET failed_login_attempts = $2,
           locked_until = $3,
           updated_at = now()
       WHERE id = $1`,
      [user.id, nextAttempts, lockedUntil?.toISOString() ?? null],
    );

    await recordAuthAnomaly({
      eventType: shouldLock ? 'auth_account_locked' : 'auth_failed_login',
      severity: shouldLock ? 'high' : 'medium',
      userId: user.id,
      req,
      payload: {
        email,
        failure_reason: failureReason,
        failed_login_attempts: nextAttempts,
        locked_until: lockedUntil?.toISOString() ?? null,
      },
    });
  }

  await recordLoginAttempt({
    email,
    userId: user?.id ?? null,
    successFlag: false,
    failureReason,
    req,
  });
}

async function recordSuccessfulLogin(userId) {
  await query(
    `UPDATE users
     SET last_login_at = now(),
         failed_login_attempts = 0,
         locked_until = NULL,
         updated_at = now()
     WHERE id = $1`,
    [userId],
  );
}

async function resolveOptionalAuth(req) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return null;
  }

  const auth = verifyAccessToken(token);
  await assertAccessSessionActive(auth.sid);
  req.auth = auth;
  return auth;
}

async function recordMfaChallengeFailure(actionToken, req, code) {
  const nextAttemptCount = Number(actionToken.attempt_count ?? 0) + 1;
  await query(
    `UPDATE auth_action_tokens
     SET attempt_count = $2,
         last_attempt_at = now(),
         revoked_at = CASE WHEN $2 >= max_attempts THEN now() ELSE revoked_at END,
         revoke_reason = CASE WHEN $2 >= max_attempts THEN 'too_many_attempts' ELSE revoke_reason END,
         updated_at = now()
     WHERE id = $1`,
    [actionToken.id, nextAttemptCount],
  );

  await recordAuthAnomaly({
    eventType: 'auth_mfa_challenge_failed',
    severity: nextAttemptCount >= Number(actionToken.max_attempts ?? 5) ? 'high' : 'medium',
    userId: actionToken.user_id,
    req,
    payload: {
      challenge_id: actionToken.uuid,
      attempt_count: nextAttemptCount,
      code_length: String(code || '').trim().length,
    },
  });
}

async function buildAuthPayload(user, req, currentSession = null) {
  const canonicalUser = {
    ...user,
    roles: canonicalizeRoles(user.roles || []),
    primary_role: resolvePrimaryMobileRole(user.roles || [], user.primary_role),
  };
  const sessionBundle = await issueSessionTokens({ user: canonicalUser, req, currentSession });
  return {
    token: sessionBundle.token,
    refresh_token: sessionBundle.refreshToken,
    session_id: sessionBundle.session.uuid,
    user: serializeUser(canonicalUser),
  };
}

function buildAuthRouter() {
  const router = express.Router();

  router.post('/register', asyncHandler(async (req, res) => {
    const payload = registerSchema.parse(req.body ?? {});
    const selectedRole = canonicalizeRole(normalizeRole(payload.role) || 'buyer');
    if (!isAllowedMobileRegistrationRole(selectedRole)) {
      throw badRequest('This role cannot be created from the Android app.');
    }

    const normalizedPhoneNumber = normalizeCameroonPhoneNumber(
      payload.phone_number,
      payload.phone_country_code,
    );

    const existing = await query(
      'SELECT id FROM users WHERE email = $1 OR phone_number = $2 LIMIT 1',
      [payload.email.toLowerCase(), normalizedPhoneNumber],
    );
    if (existing.rowCount > 0) {
      throw conflict('Email or phone number already exists.');
    }

    const passwordHash = await hashPassword(payload.password);
    const user = await withTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO users (
            email, phone_number, phone_country_code, password_hash,
            first_name, last_name, date_of_birth, preferred_language, profile_image_url,
            terms_accepted_at, privacy_accepted_at
         )
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'',now(),now())
         RETURNING id, uuid, email, phone_number, first_name, last_name, profile_image_url, preferred_language, bio, is_active, two_factor_enabled`,
        [
          payload.email.toLowerCase(),
          normalizedPhoneNumber,
          payload.phone_country_code,
          passwordHash,
          payload.first_name.trim(),
          payload.last_name.trim(),
          payload.date_of_birth,
          config.defaultLanguage,
        ],
      );

      const userRow = inserted.rows[0];

      await client.query(
        `INSERT INTO user_roles (user_id, role, is_primary)
         VALUES ($1, $2, true)
         ON CONFLICT (user_id, role) DO NOTHING`,
        [userRow.id, selectedRole],
      );

      await client.query(
        `INSERT INTO user_preferences (user_id, locale)
         VALUES ($1, $2)
         ON CONFLICT (user_id) DO NOTHING`,
        [userRow.id, config.defaultLanguage],
      );

      await client.query(
        `INSERT INTO in_app_notifications (
            user_id, notification_type, title, body, severity, category, expires_at
         )
         VALUES (
           $1,
           'welcome',
           'Welcome to Real Estate Secure',
           'Your secure property workspace is ready.',
           'success',
           'account',
           now() + interval '45 days'
         )`,
        [userRow.id],
      );

      return {
        ...userRow,
        roles: [selectedRole],
        primary_role: selectedRole,
        email_verified: false,
        phone_verified: false,
        is_verified: false,
      };
    });

    await appendOutboxEvent({
      topic: 'user.registered',
      aggregateType: 'user',
      aggregateId: user.uuid,
      eventKey: `user.registered:${user.uuid}:${req.requestId}`,
      payload: {
        user_uuid: user.uuid,
        email: user.email,
        primary_role: selectedRole,
      },
    });

    const authPayload = await buildAuthPayload(user, req);
    return success(res, authPayload, undefined, 201);
  }));

  router.post('/login', loginRateLimiter, asyncHandler(async (req, res) => {
    const payload = loginSchema.parse(req.body ?? {});
    const normalizedEmail = payload.email.toLowerCase();
    const user = await fetchAuthUserByEmail(normalizedEmail);

    if (user) {
      assertAccountNotLocked(user);
    }

    if (!user || !(await verifyPassword(payload.password, user.password_hash))) {
      await handleFailedLogin({
        user,
        email: normalizedEmail,
        failureReason: 'invalid_credentials',
        req,
      });
      throw unauthorized('Invalid email or password.');
    }
    if (!user.is_active || user.is_suspended) {
      await handleFailedLogin({
        user,
        email: normalizedEmail,
        failureReason: 'inactive_or_suspended',
        req,
      });
      throw unauthorized('This account is not available for sign-in.');
    }
    if (hasRestrictedMobileRole(user.roles)) {
      await handleFailedLogin({
        user,
        email: normalizedEmail,
        failureReason: 'restricted_mobile_role',
        req,
      });
      throw forbidden(
        'This account uses the separate administration system and cannot sign in from the Android app.',
      );
    }

    if (user.two_factor_enabled) {
      const secret = decryptTotpSecret(user.two_factor_secret);
      if (!secret) {
        throw badRequest('Two-factor authentication is enabled but not configured correctly.');
      }

      if (!payload.two_factor_code) {
        const action = await createActionToken({
          userId: user.id,
          actionType: 'mfa_login',
          ttlMinutes: 5,
          targetValue: user.email,
          metadata: {
            request_id: req.requestId,
            device_id: req.headers['x-device-id'] ?? null,
            flow: 'password_login',
          },
          maxAttempts: 5,
        });

        return success(res, {
          mfa_required: true,
          mfa_token: action.token,
          expires_in: 5 * 60,
        });
      }

      if (!verifyTotpCode(secret, payload.two_factor_code)) {
        await handleFailedLogin({
          user,
          email: normalizedEmail,
          failureReason: 'invalid_mfa_code',
          req,
        });
        throw unauthorized('The two-factor authentication code is invalid.');
      }
    }

    await recordSuccessfulLogin(user.id);
    await recordLoginAttempt({
      email: normalizedEmail,
      userId: user.id,
      successFlag: true,
      req,
    });

    const authPayload = await buildAuthPayload(user, req);
    return success(res, authPayload);
  }));

  router.post('/refresh', refreshRateLimiter, asyncHandler(async (req, res) => {
    const payload = refreshSchema.parse(req.body ?? {});
    const currentSession = await verifyRefreshSession(payload.refresh_token, req);
    const user = await fetchUserProfileByUuid(currentSession.user_uuid);
    if (hasRestrictedMobileRole(user.roles)) {
      throw forbidden(
        'This account uses the separate administration system and cannot sign in from the Android app.',
      );
    }

    const authPayload = await buildAuthPayload(user, req, currentSession);
    return success(res, authPayload);
  }));

  router.post('/logout', requireAuth, asyncHandler(async (req, res) => {
    const sessionUuid = String(req.auth?.sid || req.body?.session_id || '').trim();
    if (!sessionUuid) {
      throw badRequest('session_id is required.');
    }
    await revokeAccessSession(sessionUuid, 'logout');
    return success(res, { logged_out: true });
  }));

  router.post('/logout-all', requireAuth, asyncHandler(async (req, res) => {
    if (!req.auth?.uid) {
      throw unauthorized();
    }
    const count = await revokeAllUserSessions(req.auth.uid, 'forced_logout');
    return success(res, { logged_out: true, revoked_sessions: count });
  }));

  router.post('/forgot-password', passwordResetRateLimiter, asyncHandler(async (req, res) => {
    const payload = forgotPasswordSchema.parse(req.body ?? {});
    const userResult = await query(
      `SELECT id, uuid, email, first_name, preferred_language, is_active, is_suspended
       FROM users
       WHERE email = $1
       LIMIT 1`,
      [payload.email.toLowerCase()],
    );
    const user = userResult.rows[0] ?? null;

    if (user && user.is_active && !user.is_suspended) {
      const action = await createActionToken({
        userId: user.id,
        actionType: 'password_reset',
        ttlMinutes: config.passwordResetTokenTtlMinutes,
        targetValue: user.email,
        metadata: {
          requested_via: 'mobile_app',
          request_id: req.requestId,
        },
      });

      await createInAppNotification({
        userId: user.id,
        notificationType: 'password_reset_requested',
        title: 'Password reset requested',
        body: 'A password reset request was issued for your account. If this was not you, review your account security immediately.',
        severity: 'warning',
        category: 'security',
      });

      await queueTemplatedNotification({
        userId: user.id,
        channel: 'email',
        recipient: user.email,
        templateName: 'password_reset',
        locale: user.preferred_language ?? config.defaultLanguage,
        variables: {
          first_name: user.first_name || 'there',
          reset_token: action.token,
          expires_at: new Date(action.expiresAt).toISOString(),
        },
        metadata: {
          action_type: 'password_reset',
          user_uuid: user.uuid,
        },
      });

      await appendOutboxEvent({
        topic: 'user.password_reset_requested',
        aggregateType: 'user',
        aggregateId: user.uuid,
        eventKey: `user.password_reset_requested:${user.uuid}:${req.requestId}`,
        payload: {
          user_uuid: user.uuid,
        },
      });

      return success(res, {
        accepted: true,
        delivery: 'email',
        ...previewPayload(action),
      });
    }

    return success(res, { accepted: true, delivery: 'email' });
  }));

  router.post('/reset-password', asyncHandler(async (req, res) => {
    const payload = resetPasswordSchema.parse(req.body ?? {});
    const actionToken = await findActionTokenByToken('password_reset', payload.token);
    const userResult = await query(
      `SELECT id, uuid, email, first_name
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [actionToken.user_id],
    );
    const user = userResult.rows[0];
    if (!user) {
      throw unauthorized('This security token is invalid.');
    }

    const targetEmail = getTokenTargetValue(actionToken);
    if (targetEmail && String(user.email).toLowerCase() !== String(targetEmail).toLowerCase()) {
      throw unauthorized('This security token is invalid.');
    }

    const passwordHash = await hashPassword(payload.password);
    await withTransaction(async (client) => {
      await client.query(
        `UPDATE users
         SET password_hash = $2,
             updated_at = now()
         WHERE id = $1`,
        [user.id, passwordHash],
      );
      await client.query(
        `UPDATE auth_action_tokens
         SET consumed_at = now(),
             updated_at = now()
         WHERE id = $1`,
        [actionToken.id],
      );
    });

    await revokeAllUserSessions(user.id, 'password_reset');
    await createInAppNotification({
      userId: user.id,
      notificationType: 'password_reset_completed',
      title: 'Password changed',
      body: 'Your password has been updated and other sessions were signed out for safety.',
      severity: 'success',
      category: 'security',
    });
    await appendOutboxEvent({
      topic: 'user.password_reset_completed',
      aggregateType: 'user',
      aggregateId: user.uuid,
      eventKey: `user.password_reset_completed:${user.uuid}:${req.requestId}`,
      payload: {
        user_uuid: user.uuid,
      },
    });

    return success(res, { reset: true, logged_out_other_sessions: true });
  }));

  router.post('/2fa/enable', requireAuth, asyncHandler(async (req, res) => {
    const user = await fetchAuthUserById(req.auth.uid);
    if (!user) {
      throw notFound('User not found.');
    }

    if (user.two_factor_enabled && req.body?.force !== true) {
      return success(res, { accepted: true, already_enabled: true });
    }

    const secret = generateTotpSecret();
    await query(
      `UPDATE users
       SET two_factor_secret = $2,
           two_factor_enabled = false,
           updated_at = now()
       WHERE id = $1`,
      [user.id, encryptTotpSecret(secret)],
    );

    return success(res, {
      accepted: true,
      secret,
      otpauth_url: buildOtpAuthUrl({ accountName: user.email, secret }),
      issuer: config.mfaTotpIssuer,
      digits: config.mfaTotpDigits,
      period_sec: config.mfaTotpStepSec,
    });
  }));

  router.post('/2fa/verify', asyncHandler(async (req, res) => {
    const payload = twoFactorVerifySchema.parse(req.body ?? {});

    if (payload.mfa_token) {
      const actionToken = await findActionTokenByToken('mfa_login', payload.mfa_token);
      const user = await fetchAuthUserById(actionToken.user_id);
      if (!user) {
        throw notFound('User not found.');
      }

      const secret = decryptTotpSecret(user.two_factor_secret);
      if (!secret || !verifyTotpCode(secret, payload.code)) {
        await recordMfaChallengeFailure(actionToken, req, payload.code);
        throw unauthorized('The two-factor authentication code is invalid.');
      }

      await consumeActionToken(actionToken.id);
      await recordSuccessfulLogin(user.id);
      await recordLoginAttempt({
        email: user.email,
        userId: user.id,
        successFlag: true,
        req,
      });
      const authPayload = await buildAuthPayload(user, req);
      return success(res, authPayload);
    }

    const auth = await resolveOptionalAuth(req);
    if (!auth?.uid) {
      throw unauthorized();
    }

    const user = await fetchAuthUserById(auth.uid);
    if (!user) {
      throw notFound('User not found.');
    }

    const secret = decryptTotpSecret(user.two_factor_secret);
    if (!secret || !verifyTotpCode(secret, payload.code)) {
      throw unauthorized('The two-factor authentication code is invalid.');
    }

    await query(
      `UPDATE users
       SET two_factor_enabled = true,
           updated_at = now()
       WHERE id = $1`,
      [user.id],
    );

    await createInAppNotification({
      userId: user.id,
      notificationType: 'two_factor_enabled',
      title: 'Two-factor authentication enabled',
      body: 'Your account now requires a TOTP code for secure sign-in.',
      severity: 'success',
      category: 'security',
    });

    return success(res, { accepted: true, enabled: true });
  }));

  router.post('/biometric/register', requireAuth, asyncHandler(async (req, res) => {
    const payload = biometricRegisterSchema.parse(req.body ?? {});

    await query(
      `INSERT INTO biometric_registrations (
          user_id, credential_id, public_key, device_name, device_type, is_active, created_at
       )
       VALUES ($1,$2,$3,$4,$5,true,now())
       ON CONFLICT (credential_id)
       DO UPDATE SET
         public_key = EXCLUDED.public_key,
         device_name = EXCLUDED.device_name,
         device_type = EXCLUDED.device_type,
         is_active = true,
         last_used_at = NULL`,
      [
        req.auth.uid,
        payload.credential_id,
        payload.public_key,
        payload.device_name ?? null,
        payload.device_type ?? null,
      ],
    );

    return success(res, { accepted: true, registered: true }, undefined, 201);
  }));

  router.post('/biometric/verify', asyncHandler(async (req, res) => {
    const payload = biometricVerifySchema.parse(req.body ?? {});
    const result = await query(
      `SELECT br.*, u.uuid AS user_uuid
       FROM biometric_registrations br
       JOIN users u ON u.id = br.user_id
       WHERE br.credential_id = $1
         AND br.is_active = true
       LIMIT 1`,
      [payload.credential_id],
    );
    const registration = result.rows[0];
    if (!registration) {
      throw unauthorized('The biometric credential could not be verified.');
    }

    const verifier = crypto.createVerify('RSA-SHA256');
    verifier.update(payload.challenge);
    verifier.end();
    const signatureValid = verifier.verify(
      registration.public_key,
      Buffer.from(payload.signature, 'base64url'),
    );

    if (!signatureValid) {
      await recordAuthAnomaly({
        eventType: 'auth_biometric_failed',
        severity: 'high',
        userId: registration.user_id,
        req,
        payload: {
          credential_id: payload.credential_id,
        },
      });
      throw unauthorized('The biometric credential could not be verified.');
    }

    await query(
      `UPDATE biometric_registrations
       SET last_used_at = now()
       WHERE id = $1`,
      [registration.id],
    );

    const user = await fetchUserProfileByUuid(registration.user_uuid);
    const authPayload = await buildAuthPayload(user, req);
    return success(res, authPayload);
  }));

  return router;
}

module.exports = { buildAuthRouter };

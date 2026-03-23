const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const { query, withTransaction } = require('../db');
const { config } = require('../config');
const { unauthorized } = require('../lib/errors');
const { tokenHash } = require('./field-crypto');
const { getRedis } = require('./redis-service');

function hashPassword(password) {
  return bcrypt.hash(password, config.bcryptRounds);
}

function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

function resolveDeviceInfo(req) {
  return {
    deviceId: String(req.headers['x-device-id'] || req.body?.device_id || '').trim() || null,
    deviceName: String(req.headers['x-device-name'] || req.body?.device_name || '').trim() || null,
    platform: String(req.headers['x-client-platform'] || req.body?.platform || '').trim() || null,
    appVersion: String(req.headers['x-app-version'] || req.body?.app_version || '').trim() || null,
  };
}

function signAccessToken(user, session) {
  return jwt.sign(
    {
      sub: user.uuid,
      uid: user.id,
      email: user.email,
      roles: user.roles || [],
      sid: session.uuid,
      type: 'access',
    },
    config.jwtSecret,
    {
      expiresIn: config.accessTokenTtl,
      issuer: config.jwtIssuer,
      audience: config.jwtAudience,
    },
  );
}

function verifyAccessToken(token) {
  return jwt.verify(token, config.jwtSecret, {
    issuer: config.jwtIssuer,
    audience: config.jwtAudience,
  });
}

function buildOpaqueRefreshToken() {
  return crypto.randomBytes(48).toString('base64url');
}

async function cacheSessionState(sessionUuid, state, ttlSeconds = 900) {
  const redis = getRedis();
  if (!redis) {
    return;
  }
  await redis.set(`session:${sessionUuid}`, state, 'EX', ttlSeconds).catch(() => {});
}

async function loadSessionByToken(refreshToken) {
  const result = await query(
    `SELECT rs.*, u.uuid AS user_uuid, u.email, u.first_name, u.last_name,
            COALESCE(
              array_agg(ur.role::text ORDER BY ur.is_primary DESC, ur.role)
                FILTER (WHERE ur.role IS NOT NULL),
              ARRAY[]::text[]
            ) AS roles
     FROM refresh_sessions rs
     JOIN users u ON u.id = rs.user_id
     LEFT JOIN user_roles ur ON ur.user_id = u.id
     WHERE rs.token_hash = $1
     GROUP BY rs.id, u.id
     LIMIT 1`,
    [tokenHash(refreshToken)],
  );
  return result.rows[0] ?? null;
}

async function revokeSessionFamily(sessionFamilyId, reason) {
  await query(
    `UPDATE refresh_sessions
     SET revoked_at = COALESCE(revoked_at, now()),
         revoke_reason = COALESCE(revoke_reason, $2),
         compromised_at = CASE
           WHEN $2 = 'reuse_detected' THEN now()
           ELSE compromised_at
         END,
         updated_at = now()
     WHERE session_family_id = $1`,
    [sessionFamilyId, reason],
  );
}

async function createRefreshSession({ user, req, sessionFamilyId = null, parentSessionId = null }) {
  const refreshToken = buildOpaqueRefreshToken();
  const device = resolveDeviceInfo(req);
  const expiresAt = new Date(Date.now() + config.refreshSessionMaxDays * 24 * 60 * 60 * 1000);
  const familyId = sessionFamilyId ?? crypto.randomUUID();

  const result = await query(
    `INSERT INTO refresh_sessions (
        user_id, session_family_id, parent_session_id, token_hash,
        device_id, device_name, platform, app_version, ip_address, user_agent, expires_at
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     RETURNING id, uuid, session_family_id, expires_at`,
    [
      user.id,
      familyId,
      parentSessionId,
      tokenHash(refreshToken),
      device.deviceId,
      device.deviceName,
      device.platform,
      device.appVersion,
      req.ip ?? null,
      req.headers['user-agent'] ?? null,
      expiresAt.toISOString(),
    ],
  );

  const session = result.rows[0];
  await cacheSessionState(session.uuid, 'active');
  return { refreshToken, session };
}

async function rotateRefreshSession(currentSession, req) {
  const user = {
    id: currentSession.user_id,
    uuid: currentSession.user_uuid,
    email: currentSession.email,
    roles: currentSession.roles,
  };
  return withTransaction(async (client) => {
    const refreshToken = buildOpaqueRefreshToken();
    const device = resolveDeviceInfo(req);
    const expiresAt = new Date(Date.now() + config.refreshSessionMaxDays * 24 * 60 * 60 * 1000);

    const inserted = await client.query(
      `INSERT INTO refresh_sessions (
          user_id, session_family_id, parent_session_id, token_hash,
          device_id, device_name, platform, app_version, ip_address, user_agent, expires_at
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING id, uuid, session_family_id, expires_at`,
      [
        user.id,
        currentSession.session_family_id,
        currentSession.id,
        tokenHash(refreshToken),
        device.deviceId ?? currentSession.device_id,
        device.deviceName ?? currentSession.device_name,
        device.platform ?? currentSession.platform,
        device.appVersion ?? currentSession.app_version,
        req.ip ?? null,
        req.headers['user-agent'] ?? null,
        expiresAt.toISOString(),
      ],
    );

    await client.query(
      `UPDATE refresh_sessions
       SET rotated_at = now(),
           revoked_at = now(),
           revoke_reason = 'rotated',
           replaced_by_id = $2,
           last_used_at = now(),
           updated_at = now()
       WHERE id = $1`,
      [currentSession.id, inserted.rows[0].id],
    );

    return {
      refreshToken,
      session: inserted.rows[0],
      user,
    };
  });
}

async function issueSessionTokens({ user, req, currentSession = null }) {
  if (currentSession) {
    const rotated = await rotateRefreshSession(currentSession, req);
    await cacheSessionState(currentSession.uuid, 'revoked');
    await cacheSessionState(rotated.session.uuid, 'active');
    return {
      token: signAccessToken(user, rotated.session),
      refreshToken: rotated.refreshToken,
      session: rotated.session,
    };
  }

  const created = await createRefreshSession({ user, req });
  return {
    token: signAccessToken(user, created.session),
    refreshToken: created.refreshToken,
    session: created.session,
  };
}

async function verifyRefreshSession(refreshToken, req) {
  const session = await loadSessionByToken(refreshToken);
  if (!session) {
    throw unauthorized('Refresh session is invalid.');
  }
  if (session.revoked_at || session.is_forced_logout || new Date(session.expires_at).getTime() <= Date.now()) {
    if (session.replaced_by_id || session.rotated_at) {
      await revokeSessionFamily(session.session_family_id, 'reuse_detected');
    }
    await cacheSessionState(session.uuid, 'revoked');
    throw unauthorized('Refresh session is no longer valid.');
  }

  const device = resolveDeviceInfo(req);
  if (session.device_id && device.deviceId && session.device_id !== device.deviceId) {
    await revokeSessionFamily(session.session_family_id, 'device_mismatch');
    await cacheSessionState(session.uuid, 'revoked');
    throw unauthorized('Refresh session device validation failed.');
  }

  await query(
    `UPDATE refresh_sessions
     SET last_used_at = now(),
         ip_address = $2,
         user_agent = $3,
         updated_at = now()
     WHERE id = $1`,
    [session.id, req.ip ?? null, req.headers['user-agent'] ?? null],
  );
  await cacheSessionState(session.uuid, 'active');

  return session;
}

async function revokeAccessSession(sessionUuid, reason = 'logout') {
  const result = await query(
    `UPDATE refresh_sessions
     SET revoked_at = now(),
         revoke_reason = $2,
         is_forced_logout = CASE WHEN $2 = 'forced_logout' THEN true ELSE is_forced_logout END,
         updated_at = now()
     WHERE uuid = $1
     RETURNING session_family_id`,
    [sessionUuid, reason],
  );
  if (result.rows[0]) {
    await cacheSessionState(sessionUuid, 'revoked');
  }
  return result.rows[0] ?? null;
}

async function revokeAllUserSessions(userId, reason = 'forced_logout') {
  const result = await query(
    `UPDATE refresh_sessions
     SET revoked_at = now(),
         revoke_reason = $2,
         is_forced_logout = true,
         updated_at = now()
     WHERE user_id = $1
       AND revoked_at IS NULL
     RETURNING uuid`,
    [userId, reason],
  );
  await Promise.all(result.rows.map((row) => cacheSessionState(row.uuid, 'revoked')));
  return result.rowCount;
}

async function assertAccessSessionActive(sessionUuid) {
  if (!sessionUuid) {
    throw unauthorized('Your session is invalid or has expired.');
  }

  const redis = getRedis();
  if (redis) {
    const cached = await redis.get(`session:${sessionUuid}`).catch(() => null);
    if (cached === 'active') {
      return true;
    }
    if (cached === 'revoked') {
      throw unauthorized('Your session is invalid or has expired.');
    }
  }

  const result = await query(
    `SELECT uuid
     FROM refresh_sessions
     WHERE uuid = $1
       AND revoked_at IS NULL
       AND is_forced_logout = false
       AND expires_at > now()
     LIMIT 1`,
    [sessionUuid],
  );
  if (!result.rows[0]) {
    await cacheSessionState(sessionUuid, 'revoked');
    throw unauthorized('Your session is invalid or has expired.');
  }

  await cacheSessionState(sessionUuid, 'active');
  return true;
}

module.exports = {
  assertAccessSessionActive,
  hashPassword,
  issueSessionTokens,
  revokeAccessSession,
  revokeAllUserSessions,
  verifyAccessToken,
  verifyPassword,
  verifyRefreshSession,
};

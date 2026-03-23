const crypto = require('crypto');

const { query } = require('../db');
const { config } = require('../config');
const { badRequest, unauthorized } = require('../lib/errors');
const { decryptValueSafely, encryptValue, tokenHash } = require('./field-crypto');

function buildOpaqueToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function buildNumericCode(length = 6) {
  const alphabet = '0123456789';
  let code = '';
  for (let index = 0; index < length; index += 1) {
    code += alphabet[crypto.randomInt(0, alphabet.length)];
  }
  return code;
}

function computeExpiry(minutes) {
  return new Date(Date.now() + minutes * 60 * 1000);
}

async function revokeActiveTokens(userId, actionType, reason = 'reissued') {
  await query(
    `UPDATE auth_action_tokens
     SET revoked_at = now(),
         revoke_reason = COALESCE(revoke_reason, $3),
         updated_at = now()
     WHERE user_id = $1
       AND action_type = $2
       AND consumed_at IS NULL
       AND revoked_at IS NULL`,
    [userId, actionType, reason],
  );
}

async function createActionToken({
  userId,
  actionType,
  ttlMinutes,
  targetValue = null,
  metadata = {},
  asCode = false,
  maxAttempts = 5,
}) {
  await revokeActiveTokens(userId, actionType);

  const token = asCode ? null : buildOpaqueToken();
  const code = asCode ? buildNumericCode() : null;
  const expiresAt = computeExpiry(ttlMinutes);
  const result = await query(
    `INSERT INTO auth_action_tokens (
        user_id, action_type, token_hash, code_hash, target_value, metadata, max_attempts, expires_at
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING id, uuid, expires_at`,
    [
      userId,
      actionType,
      token ? tokenHash(token) : null,
      code ? tokenHash(code) : null,
      encryptValue(targetValue),
      JSON.stringify(metadata ?? {}),
      maxAttempts,
      expiresAt.toISOString(),
    ],
  );

  return {
    record: result.rows[0],
    token,
    code,
    expiresAt: result.rows[0]?.expires_at ?? expiresAt.toISOString(),
  };
}

function assertActiveToken(row, invalidMessage) {
  if (!row) {
    throw unauthorized(invalidMessage);
  }
  if (row.consumed_at || row.revoked_at) {
    throw unauthorized(invalidMessage);
  }
  if (new Date(row.expires_at).getTime() <= Date.now()) {
    throw unauthorized('This security token has expired.');
  }
  if (Number(row.attempt_count ?? 0) >= Number(row.max_attempts ?? 5)) {
    throw unauthorized('This security token is no longer valid.');
  }
}

async function findActionTokenByToken(actionType, token) {
  const result = await query(
    `SELECT *
     FROM auth_action_tokens
     WHERE action_type = $1
       AND token_hash = $2
     ORDER BY created_at DESC
     LIMIT 1`,
    [actionType, tokenHash(token)],
  );
  const row = result.rows[0] ?? null;
  assertActiveToken(row, 'This security token is invalid.');
  return row;
}

async function findLatestActionTokenForUser(userId, actionType) {
  const result = await query(
    `SELECT *
     FROM auth_action_tokens
     WHERE user_id = $1
       AND action_type = $2
       AND consumed_at IS NULL
       AND revoked_at IS NULL
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId, actionType],
  );
  return result.rows[0] ?? null;
}

async function verifyActionCode({
  userId,
  actionType,
  code,
  missingMessage = 'No active verification code was found.',
  invalidMessage = 'The verification code is invalid.',
}) {
  const latest = await findLatestActionTokenForUser(userId, actionType);
  assertActiveToken(latest, missingMessage);

  if (latest.code_hash !== tokenHash(code)) {
    const nextAttemptCount = Number(latest.attempt_count ?? 0) + 1;
    await query(
      `UPDATE auth_action_tokens
       SET attempt_count = $2,
           last_attempt_at = now(),
           revoked_at = CASE WHEN $2 >= max_attempts THEN now() ELSE revoked_at END,
           revoke_reason = CASE WHEN $2 >= max_attempts THEN 'too_many_attempts' ELSE revoke_reason END,
           updated_at = now()
       WHERE id = $1`,
      [latest.id, nextAttemptCount],
    );
    throw badRequest(invalidMessage);
  }

  await query(
    `UPDATE auth_action_tokens
     SET attempt_count = attempt_count + 1,
         last_attempt_at = now(),
         updated_at = now()
     WHERE id = $1`,
    [latest.id],
  );
  return latest;
}

async function consumeActionToken(id) {
  await query(
    `UPDATE auth_action_tokens
     SET consumed_at = now(),
         updated_at = now()
     WHERE id = $1`,
    [id],
  );
}

function previewPayload({ token = null, code = null, expiresAt = null }) {
  if (!config.exposeActionTokenPreview) {
    return {};
  }

  return {
    preview_token: token,
    preview_code: code,
    preview_expires_at: expiresAt,
  };
}

function getTokenTargetValue(row) {
  return decryptValueSafely(row?.target_value);
}

module.exports = {
  consumeActionToken,
  createActionToken,
  findActionTokenByToken,
  findLatestActionTokenForUser,
  getTokenTargetValue,
  previewPayload,
  revokeActiveTokens,
  verifyActionCode,
};

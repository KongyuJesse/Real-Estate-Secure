const crypto = require('crypto');

const { query } = require('../db');
const { badRequest, conflict } = require('../lib/errors');

function buildRequestHash(req) {
  return crypto
    .createHash('sha256')
    .update(
      JSON.stringify({
        method: req.method,
        path: req.originalUrl,
        body: req.body ?? {},
      }),
    )
    .digest('hex');
}

function withIdempotency({ ttlSeconds = 3600 } = {}) {
  return async (req, res, next) => {
    const key = String(req.headers['idempotency-key'] || '').trim();
    if (!key) {
      return next();
    }

    const scopeKey = `${req.auth?.uid ?? 'anon'}:${req.method}:${req.baseUrl}${req.path}:${key}`;
    const requestHash = buildRequestHash(req);
    const existing = await query(
      `SELECT response_status, response_body, request_hash
       FROM api_idempotency_keys
       WHERE scope_key = $1
         AND expires_at > now()
       LIMIT 1`,
      [scopeKey],
    );

    if (existing.rows[0]) {
      if (existing.rows[0].request_hash !== requestHash) {
        return next(conflict('This idempotency key was already used with a different payload.'));
      }
      if (existing.rows[0].response_status && existing.rows[0].response_body) {
        return res.status(existing.rows[0].response_status).json(existing.rows[0].response_body);
      }
      return next(badRequest('This idempotency key is already being processed.'));
    }

    await query(
      `INSERT INTO api_idempotency_keys (
          scope_key, user_id, request_method, request_path, request_hash, expires_at
       )
       VALUES ($1,$2,$3,$4,$5, now() + ($6 || ' seconds')::interval)`,
      [scopeKey, req.auth?.uid ?? null, req.method, `${req.baseUrl}${req.path}`, requestHash, String(ttlSeconds)],
    );

    const originalJson = res.json.bind(res);
    res.json = async (body) => {
      await query(
        `UPDATE api_idempotency_keys
         SET response_status = $2,
             response_body = $3,
             locked_at = now()
         WHERE scope_key = $1`,
        [scopeKey, res.statusCode, JSON.stringify(body)],
      ).catch(() => {});
      return originalJson(body);
    };

    return next();
  };
}

module.exports = {
  withIdempotency,
};

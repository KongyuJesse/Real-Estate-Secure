const express = require('express');

const { query } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { getPagination } = require('../lib/pagination');
const { badRequest, notFound } = require('../lib/errors');
const { encryptValue } = require('../services/field-crypto');

async function archiveStaleNotifications(userId) {
  await query(
    `UPDATE in_app_notifications
     SET status = 'archived', updated_at = now()
     WHERE user_id = $1
       AND status <> 'archived'
       AND (
         (expires_at IS NOT NULL AND expires_at <= now())
         OR (status = 'read' AND COALESCE(read_at, created_at) <= now() - interval '21 days')
         OR (status = 'unread' AND created_at <= now() - interval '60 days')
       )`,
    [userId],
  );
}

function buildNotificationsRouter() {
  const router = express.Router();

  router.get('/', asyncHandler(async (req, res) => {
    await archiveStaleNotifications(req.auth.uid);
    const { limit, offset, page } = getPagination(req.query);
    const status = req.query.status ? String(req.query.status) : null;
    const result = await query(
      `SELECT uuid AS id, notification_type, title, body, severity, category, status, action_url, action_label, created_at
       FROM in_app_notifications
       WHERE user_id = $1
         AND status <> 'archived'
         AND (expires_at IS NULL OR expires_at > now())
         AND ($2::text IS NULL OR status = $2::text)
       ORDER BY created_at DESC
       LIMIT $3 OFFSET $4`,
      [req.auth.uid, status, limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/unread-count', asyncHandler(async (req, res) => {
    await archiveStaleNotifications(req.auth.uid);
    const result = await query(
      `SELECT COUNT(*)::int AS unread_count
       FROM in_app_notifications
       WHERE user_id = $1
         AND status = 'unread'
         AND (expires_at IS NULL OR expires_at > now())`,
      [req.auth.uid],
    );
    return success(res, result.rows[0] ?? { unread_count: 0 });
  }));

  router.post('/read-all', asyncHandler(async (req, res) => {
    await query(
      `UPDATE in_app_notifications
       SET status = 'read', read_at = now(), updated_at = now()
       WHERE user_id = $1 AND status = 'unread'`,
      [req.auth.uid],
    );
    return success(res, { updated: true });
  }));

  router.post('/:id/read', asyncHandler(async (req, res) => {
    const updated = await query(
      `UPDATE in_app_notifications
       SET status = 'read', read_at = now(), updated_at = now()
       WHERE uuid = $1 AND user_id = $2
       RETURNING uuid AS id, status, read_at`,
      [req.params.id, req.auth.uid],
    );
    if (!updated.rows[0]) {
      throw notFound('Notification not found.');
    }
    return success(res, updated.rows[0]);
  }));

  router.delete('/:id', asyncHandler(async (req, res) => {
    const updated = await query(
      `UPDATE in_app_notifications
       SET status = 'archived', updated_at = now()
       WHERE uuid = $1
         AND user_id = $2
         AND status <> 'archived'
       RETURNING uuid AS id, status`,
      [req.params.id, req.auth.uid],
    );
    if (!updated.rows[0]) {
      throw notFound('Notification not found.');
    }
    return success(res, { archived: true, id: updated.rows[0].id });
  }));

  router.get('/devices', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT uuid AS id, push_provider, platform, device_name, locale, is_active, last_seen_at
       FROM push_devices
       WHERE user_id = $1
       ORDER BY last_seen_at DESC`,
      [req.auth.uid],
    );
    return success(res, result.rows);
  }));

  router.post('/devices', asyncHandler(async (req, res) => {
    const { platform, device_token, device_name, locale, push_provider = 'generic' } = req.body ?? {};
    if (!platform || !device_token) {
      throw badRequest('platform and device_token are required.');
    }
    const result = await query(
      `INSERT INTO push_devices (
          user_id, push_provider, platform, device_token, device_name, locale, is_active, last_seen_at
       )
       VALUES ($1,$2,$3,$4,$5,$6,true,now())
       ON CONFLICT (user_id, device_token)
       DO UPDATE SET
         push_provider = EXCLUDED.push_provider,
         platform = EXCLUDED.platform,
         device_name = EXCLUDED.device_name,
         locale = EXCLUDED.locale,
         is_active = true,
         last_seen_at = now(),
         updated_at = now()
        RETURNING uuid AS id, platform, device_name, locale, is_active`,
      [req.auth.uid, push_provider, platform, encryptValue(device_token), device_name ?? null, locale ?? null],
    );
    return success(res, result.rows[0], undefined, 201);
  }));

  router.delete('/devices/:id', asyncHandler(async (req, res) => {
    await query(
      `UPDATE push_devices
       SET is_active = false, updated_at = now()
       WHERE uuid = $1 AND user_id = $2`,
      [req.params.id, req.auth.uid],
    );
    return success(res, { deleted: true });
  }));

  return router;
}

module.exports = { buildNotificationsRouter };

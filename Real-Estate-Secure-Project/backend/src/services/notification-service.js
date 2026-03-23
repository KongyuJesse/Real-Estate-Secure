const { query } = require('../db');

function resolveNotificationExpiry(expiresAt, severity) {
  if (expiresAt) {
    return expiresAt;
  }
  const now = Date.now();
  const retentionDays = severity === 'critical' ? 90 : 45;
  return new Date(now + retentionDays * 24 * 60 * 60 * 1000);
}

async function createInAppNotification({
  userId,
  notificationType,
  title,
  body,
  severity = 'info',
  category = 'activity',
  actionUrl = null,
  actionLabel = null,
  metadata = {},
  expiresAt = null,
  dedupeKey = null,
}) {
  if (!userId || !title || !body) {
    return null;
  }
  if (dedupeKey) {
    const existing = await query(
      `SELECT uuid AS id, status, created_at
       FROM in_app_notifications
       WHERE user_id = $1
         AND metadata ->> 'dedupe_key' = $2
       ORDER BY created_at DESC
       LIMIT 1`,
      [userId, dedupeKey],
    );
    if (existing.rows[0]) {
      return existing.rows[0];
    }
  }
  const storedMetadata = {
    ...(metadata ?? {}),
    ...(dedupeKey ? { dedupe_key: dedupeKey } : {}),
  };
  const effectiveExpiry = resolveNotificationExpiry(expiresAt, severity);
  const result = await query(
    `INSERT INTO in_app_notifications (
        user_id, notification_type, title, body, severity, category,
        action_url, action_label, metadata, expires_at
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING uuid AS id, status, created_at`,
    [
      userId,
      notificationType,
      title,
      body,
      severity,
      category,
      actionUrl,
      actionLabel,
      JSON.stringify(storedMetadata),
      effectiveExpiry,
    ],
  );
  return result.rows[0] ?? null;
}

function renderTemplate(template, variables = {}) {
  return String(template || '').replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, (_, key) => {
    const value = variables[key];
    return value === undefined || value === null ? '' : String(value);
  });
}

async function loadUserNotificationProfile(userId) {
  const result = await query(
    `SELECT
        u.id,
        u.uuid,
        u.email,
        u.phone_number,
        u.first_name,
        u.last_name,
        COALESCE(up.locale, u.preferred_language, 'en') AS locale,
        COALESCE(up.email_notifications_enabled, true) AS email_notifications_enabled,
        COALESCE(up.sms_notifications_enabled, false) AS sms_notifications_enabled,
        COALESCE(up.push_notifications_enabled, false) AS push_notifications_enabled,
        COALESCE(up.marketing_notifications_enabled, false) AS marketing_notifications_enabled
     FROM users u
     LEFT JOIN user_preferences up ON up.user_id = u.id
     WHERE u.id = $1
     LIMIT 1`,
    [userId],
  );
  return result.rows[0] ?? null;
}

async function loadTemplate(channel, templateName) {
  if (channel === 'email') {
    const result = await query(
      `SELECT template_name, subject_en, subject_fr, body_en, body_fr
       FROM email_templates
       WHERE template_name = $1
         AND is_active = true
       LIMIT 1`,
      [templateName],
    );
    return result.rows[0] ?? null;
  }

  if (channel === 'sms') {
    const result = await query(
      `SELECT template_name, body_en, body_fr
       FROM sms_templates
       WHERE template_name = $1
         AND is_active = true
       LIMIT 1`,
      [templateName],
    );
    return result.rows[0] ?? null;
  }

  return null;
}

async function queueNotificationOutbox({
  userId = null,
  channel,
  recipient,
  templateName,
  payload = {},
  subject = null,
  bodyText = null,
  bodyHtml = null,
  locale = 'en',
  providerName = null,
  sendAfter = null,
  metadata = {},
}) {
  if (!channel || !recipient || !templateName) {
    return null;
  }
  const result = await query(
    `INSERT INTO notification_outbox (
        channel, recipient, template_name, payload, send_after, user_id,
        subject, body_text, body_html, locale, metadata, provider_name
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
     RETURNING id, status, created_at`,
    [
      channel,
      recipient,
      templateName,
      JSON.stringify(payload ?? {}),
      sendAfter,
      userId,
      subject,
      bodyText,
      bodyHtml,
      locale,
      JSON.stringify(metadata ?? {}),
      providerName,
    ],
  );
  return result.rows[0] ?? null;
}

async function queueTemplatedNotification({
  userId = null,
  channel,
  recipient,
  templateName,
  variables = {},
  locale = 'en',
  providerName = null,
  sendAfter = null,
  metadata = {},
}) {
  const template = await loadTemplate(channel, templateName);
  if (!template) {
    return null;
  }

  const useFrench = String(locale || 'en').toLowerCase().startsWith('fr');
  const subject = channel === 'email'
    ? renderTemplate(useFrench ? template.subject_fr : template.subject_en, variables)
    : null;
  const bodyText = channel === 'sms'
    ? renderTemplate(useFrench ? template.body_fr : template.body_en, variables)
    : null;
  const bodyHtml = channel === 'email'
    ? renderTemplate(useFrench ? template.body_fr : template.body_en, variables)
    : null;

  return queueNotificationOutbox({
    userId,
    channel,
    recipient,
    templateName,
    payload: variables,
    subject,
    bodyText,
    bodyHtml,
    locale,
    providerName,
    sendAfter,
    metadata,
  });
}

module.exports = {
  createInAppNotification,
  loadUserNotificationProfile,
  queueNotificationOutbox,
  queueTemplatedNotification,
  renderTemplate,
};

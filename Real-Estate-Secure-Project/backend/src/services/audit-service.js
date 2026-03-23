const { query } = require('../db');
const { config } = require('../config');

async function recordAuditEvent({
  req,
  userId = null,
  action,
  entityType,
  entityId,
  oldValues = null,
  newValues = null,
  statusCode = 200,
}) {
  if (!action || !entityType || entityId === undefined || entityId === null) {
    return;
  }

  await query(
    `INSERT INTO audit_logs (
        user_id, action, entity_type, entity_id, old_values, new_values,
        ip_address, user_agent, session_id, request_id, status_code
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
    [
      userId,
      action,
      entityType,
      entityId,
      oldValues ? JSON.stringify(oldValues) : null,
      newValues ? JSON.stringify(newValues) : null,
      req.ip ?? null,
      req.headers['user-agent'] ?? null,
      req.auth?.sid ?? null,
      req.requestId ?? null,
      statusCode,
    ],
  ).catch(() => {});
}

async function recordPrivilegedRead({ req, userId = null, action, entityType, entityId, details = null }) {
  if (!config.auditPrivilegedReads) {
    return;
  }

  return recordAuditEvent({
    req,
    userId,
    action,
    entityType,
    entityId,
    newValues: details,
    statusCode: 200,
  });
}

module.exports = {
  recordAuditEvent,
  recordPrivilegedRead,
};

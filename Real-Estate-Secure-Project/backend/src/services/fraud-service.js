const { query } = require('../db');

async function recordFraudEvent({
  eventType,
  severity = 'medium',
  referenceType,
  referenceId,
  payload = {},
}) {
  if (!eventType || !referenceType || referenceId === undefined || referenceId === null) {
    return;
  }

  await query(
    `INSERT INTO fraud_events (event_type, severity, reference_type, reference_id, payload, created_at)
     VALUES ($1, $2, $3, $4, $5, now())
     ON CONFLICT (event_type, reference_type, reference_id)
     DO UPDATE SET
       severity = EXCLUDED.severity,
       payload = EXCLUDED.payload,
       created_at = now()`,
    [
      eventType,
      severity,
      referenceType,
      referenceId,
      JSON.stringify(payload || {}),
    ],
  ).catch(() => {});
}

module.exports = {
  recordFraudEvent,
};
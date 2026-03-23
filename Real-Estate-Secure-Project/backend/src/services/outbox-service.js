const { query } = require('../db');

async function appendOutboxEvent({
  topic,
  aggregateType,
  aggregateId,
  eventKey,
  payload,
  availableAt = null,
}) {
  await query(
    `INSERT INTO outbox_events (
        topic, aggregate_type, aggregate_id, event_key, payload, available_at
     )
     VALUES ($1,$2,$3,$4,$5,COALESCE($6, now()))
     ON CONFLICT (event_key) DO NOTHING`,
    [
      topic,
      aggregateType,
      String(aggregateId),
      eventKey,
      JSON.stringify(payload ?? {}),
      availableAt,
    ],
  );
}

async function listPendingOutboxEvents(limit = 50) {
  const result = await query(
    `SELECT *
     FROM outbox_events
     WHERE status = 'pending'
       AND available_at <= now()
     ORDER BY available_at ASC, created_at ASC
     LIMIT $1`,
    [limit],
  );
  return result.rows;
}

async function markOutboxPublished(id) {
  await query(
    `UPDATE outbox_events
     SET status = 'published',
         published_at = now(),
         updated_at = now()
     WHERE id = $1`,
    [id],
  );
}

async function markOutboxFailed(id, errorMessage) {
  await query(
    `UPDATE outbox_events
     SET attempts = attempts + 1,
         failure_reason = $2,
         updated_at = now()
     WHERE id = $1`,
    [id, String(errorMessage || 'unknown_error').slice(0, 2000)],
  );
}

module.exports = {
  appendOutboxEvent,
  listPendingOutboxEvents,
  markOutboxFailed,
  markOutboxPublished,
};

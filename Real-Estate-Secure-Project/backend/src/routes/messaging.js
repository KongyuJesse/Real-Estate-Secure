const express = require('express');

const { query, withTransaction } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest, notFound } = require('../lib/errors');
const { requireConversationAccess } = require('../services/authorization-service');
const { withIdempotency } = require('../services/idempotency-service');
const { appendOutboxEvent } = require('../services/outbox-service');
const { publish, subscribe } = require('../services/realtime-service');

async function listParticipantIds(conversationId) {
  const result = await query(
    `SELECT user_id
     FROM conversation_participants
     WHERE conversation_id = $1
       AND left_at IS NULL`,
    [conversationId],
  );
  return result.rows.map((row) => row.user_id);
}

function buildMessagingRouter() {
  const router = express.Router();

  router.get('/conversations', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT c.uuid AS id, c.title, c.conversation_type, c.last_message_at, c.last_message_preview, cp.last_read_at
       FROM conversation_participants cp
       JOIN conversations c ON c.id = cp.conversation_id
       WHERE cp.user_id = $1 AND cp.left_at IS NULL
       ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC`,
      [req.auth.uid],
    );
    return success(res, result.rows);
  }));

  router.post('/conversations', withIdempotency(), asyncHandler(async (req, res) => {
    const participants = Array.isArray(req.body?.participant_ids)
      ? req.body.participant_ids.filter(Boolean)
      : [];

    const created = await withTransaction(async (client) => {
      const conversation = await client.query(
        `INSERT INTO conversations (property_id, transaction_id, conversation_type, title, last_message_at)
         VALUES (
           (SELECT id FROM properties WHERE uuid = $1),
           (SELECT id FROM transactions WHERE uuid = $2),
           COALESCE($3, 'direct'),
           $4,
           now()
         )
         RETURNING id, uuid, conversation_type, title`,
        [
          req.body?.property_id ?? null,
          req.body?.transaction_id ?? null,
          req.body?.conversation_type ?? null,
          req.body?.title ?? null,
        ],
      );
      const row = conversation.rows[0];
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id, role)
         VALUES ($1, $2, 'admin')
         ON CONFLICT (conversation_id, user_id) DO NOTHING`,
        [row.id, req.auth.uid],
      );

      for (const participantUuid of participants) {
        await client.query(
          `INSERT INTO conversation_participants (conversation_id, user_id)
           SELECT $1, u.id
           FROM users u
           WHERE u.uuid = $2
           ON CONFLICT (conversation_id, user_id) DO NOTHING`,
          [row.id, participantUuid],
        );
      }

      return row;
    });

    return success(res, created, undefined, 201);
  }));

  router.get('/conversations/:id/messages', asyncHandler(async (req, res) => {
    const conversation = await requireConversationAccess(req, req.params.id);
    const result = await query(
      `SELECT m.id, m.message_type, m.content, m.attachments, m.created_at, u.uuid AS sender_id, u.first_name, u.last_name
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.conversation_id = $1 AND m.deleted_at IS NULL
       ORDER BY m.created_at ASC`,
      [conversation.id],
    );
    return success(res, result.rows);
  }));

  router.get('/conversations/:id/stream', asyncHandler(async (req, res) => {
    const conversation = await requireConversationAccess(req, req.params.id);
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    });
    res.write(`event: ready\ndata: ${JSON.stringify({ conversation_id: conversation.uuid })}\n\n`);

    const unsubscribe = subscribe(`conversation:${conversation.uuid}`, (payload) => {
      res.write(`event: message\ndata: ${JSON.stringify(payload)}\n\n`);
    });
    const heartbeat = setInterval(() => {
      res.write(`event: heartbeat\ndata: {}\n\n`);
    }, 15000);

    req.on('close', () => {
      clearInterval(heartbeat);
      unsubscribe();
      res.end();
    });
  }));

  router.post('/conversations/:id/messages', withIdempotency(), asyncHandler(async (req, res) => {
    if (!req.body?.content) {
      throw badRequest('content is required.');
    }

    const conversation = await requireConversationAccess(req, req.params.id, { action: 'write_conversation' });
    const inserted = await query(
      `INSERT INTO messages (conversation_id, sender_id, message_type, content, attachments)
       VALUES ($1,$2,COALESCE($3, 'text'),$4,COALESCE($5, '[]'::jsonb))
       RETURNING id, created_at, message_type, content, attachments`,
      [
        conversation.id,
        req.auth.uid,
        req.body?.message_type ?? null,
        req.body.content,
        JSON.stringify(req.body?.attachments ?? []),
      ],
    );

    await query(
      `UPDATE conversations
       SET last_message_at = now(),
           last_message_preview = LEFT($2, 255),
           updated_at = now()
       WHERE uuid = $1`,
      [req.params.id, req.body.content],
    );

    const participantIds = await listParticipantIds(conversation.id);
    await Promise.all(
      participantIds
        .filter((userId) => String(userId) !== String(req.auth.uid))
        .map((userId) =>
          query(
            `INSERT INTO message_status (message_id, user_id, status)
             VALUES ($1,$2,'sent')
             ON CONFLICT (message_id, user_id) DO NOTHING`,
            [inserted.rows[0].id, userId],
          )),
    );

    await publish(`conversation:${conversation.uuid}`, {
      conversation_id: conversation.uuid,
      message_id: inserted.rows[0].id,
      sender_id: req.auth.sub,
      content: inserted.rows[0].content,
      message_type: inserted.rows[0].message_type,
      created_at: inserted.rows[0].created_at,
    });
    await appendOutboxEvent({
      topic: 'conversation.message_created',
      aggregateType: 'conversation',
      aggregateId: conversation.uuid,
      eventKey: `conversation.message_created:${conversation.uuid}:${inserted.rows[0].id}:${req.requestId}`,
      payload: {
        conversation_id: conversation.uuid,
        message_id: inserted.rows[0].id,
        sender_id: req.auth.sub,
      },
    });

    return success(res, inserted.rows[0], undefined, 201);
  }));

  router.put('/messages/:id', asyncHandler(async (req, res) => {
    const updated = await query(
      `UPDATE messages
       SET content = COALESCE($2, content), is_edited = true, edited_at = now()
       WHERE id = $1 AND sender_id = $3
       RETURNING id, content, edited_at, conversation_id`,
      [req.params.id, req.body?.content ?? null, req.auth.uid],
    );
    if (!updated.rows[0]) {
      throw notFound('Message not found.');
    }
    return success(res, updated.rows[0]);
  }));

  router.delete('/messages/:id', asyncHandler(async (req, res) => {
    await query(
      `UPDATE messages
       SET deleted_at = now()
       WHERE id = $1 AND sender_id = $2`,
      [req.params.id, req.auth.uid],
    );
    return success(res, { deleted: true });
  }));

  router.post('/conversations/:id/read', asyncHandler(async (req, res) => {
    const conversation = await requireConversationAccess(req, req.params.id, { action: 'mark_conversation_read' });
    await query(
      `UPDATE conversation_participants
       SET last_read_at = now()
       WHERE conversation_id = $1
         AND user_id = $2`,
      [conversation.id, req.auth.uid],
    );
    return success(res, { read: true });
  }));

  router.post('/conversations/:id/archive', asyncHandler(async (req, res) => {
    const conversation = await requireConversationAccess(req, req.params.id, { action: 'archive_conversation' });
    await query(
      `UPDATE conversation_participants
       SET is_archived = true
       WHERE conversation_id = $1
         AND user_id = $2`,
      [conversation.id, req.auth.uid],
    );
    return success(res, { archived: true });
  }));

  return router;
}

module.exports = { buildMessagingRouter };

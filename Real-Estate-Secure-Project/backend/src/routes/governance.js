const express = require('express');

const { query } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest, notFound } = require('../lib/errors');
const { getPagination } = require('../lib/pagination');
const { requireDisputeAccess, isAdmin } = require('../services/authorization-service');
const { withIdempotency } = require('../services/idempotency-service');
const { appendOutboxEvent } = require('../services/outbox-service');
const {
  consumeSumsubWebhook,
  refreshSumsubCaseById,
} = require('../services/sumsub-kyc-service');
const {
  assertDisputeTransition,
  assertKycTransition,
  assertOptimisticLock,
} = require('../services/workflow-service');

function buildGovernanceRouter({ requireAuth, requireRole }) {
  const router = express.Router();

  router.get('/disputes', requireAuth, asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT dispute_number, status, priority, dispute_type, created_at
       FROM disputes
       WHERE raised_by_id = $1 OR raised_against_id = $1 OR assigned_to_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.auth.uid, limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/disputes/:id', requireAuth, asyncHandler(async (req, res) => {
    const dispute = await requireDisputeAccess(req, req.params.id);
    return success(res, dispute);
  }));

  router.post('/disputes', requireAuth, withIdempotency(), asyncHandler(async (req, res) => {
    if (!req.body?.description || !req.body?.requested_resolution) {
      throw badRequest('description and requested_resolution are required.');
    }
    const result = await query(
      `INSERT INTO disputes (
          dispute_number, transaction_id, raised_by_id, raised_against_id, dispute_type,
          description, requested_resolution, priority
       )
       VALUES (
         CONCAT('DSP-', TO_CHAR(now(), 'YYYYMMDDHH24MISS'), '-', FLOOR(random() * 100000)::int),
         (SELECT id FROM transactions WHERE uuid = $1),
         $2,
         (SELECT id FROM users WHERE uuid = $3),
         COALESCE($4, 'other'),
         $5,
         $6,
         COALESCE($7, 'medium')
       )
       RETURNING dispute_number, status, created_at`,
      [
        req.body?.transaction_id ?? null,
        req.auth.uid,
        req.body?.raised_against_id ?? null,
        req.body?.dispute_type ?? null,
        req.body.description,
        req.body.requested_resolution,
        req.body?.priority ?? null,
      ],
    );
    await appendOutboxEvent({
      topic: 'dispute.created',
      aggregateType: 'dispute',
      aggregateId: result.rows[0].dispute_number,
      eventKey: `dispute.created:${result.rows[0].dispute_number}:${req.requestId}`,
      payload: {
        dispute_number: result.rows[0].dispute_number,
        transaction_id: req.body?.transaction_id ?? null,
      },
    });
    return success(res, result.rows[0], undefined, 201);
  }));

  router.post('/disputes/:id/messages', requireAuth, withIdempotency(), asyncHandler(async (req, res) => {
    const dispute = await requireDisputeAccess(req, req.params.id, { action: 'write_dispute' });
    if (req.body?.is_private === true && !isAdmin(req) && String(dispute.assigned_to_id || '') !== String(req.auth.uid)) {
      throw badRequest('Private dispute notes are reserved for assigned reviewers and administrators.');
    }
    const result = await query(
      `INSERT INTO dispute_messages (dispute_id, sender_id, message, attachments, is_private)
       VALUES (
         $1,
         $2,
         $3,
         COALESCE($4, '[]'::jsonb),
         COALESCE($5, false)
       )
       RETURNING id, created_at`,
      [dispute.id, req.auth.uid, req.body?.message ?? '', JSON.stringify(req.body?.attachments ?? []), req.body?.is_private ?? false],
    );
    await appendOutboxEvent({
      topic: 'dispute.message_created',
      aggregateType: 'dispute',
      aggregateId: dispute.dispute_number,
      eventKey: `dispute.message_created:${dispute.dispute_number}:${result.rows[0].id}:${req.requestId}`,
      payload: {
        dispute_number: dispute.dispute_number,
        message_id: result.rows[0].id,
      },
    });
    return success(res, result.rows[0], undefined, 201);
  }));

  router.get('/disputes/:id/messages', requireAuth, asyncHandler(async (req, res) => {
    const dispute = await requireDisputeAccess(req, req.params.id, { action: 'read_dispute_messages' });
    const result = await query(
      `SELECT dm.id, dm.message, dm.attachments, dm.is_private, dm.created_at, u.uuid AS sender_id, u.first_name, u.last_name
       FROM dispute_messages dm
       JOIN users u ON u.id = dm.sender_id
       WHERE dm.dispute_id = $1
         AND (dm.is_private = false OR $2::boolean = true OR $3::boolean = true)
       ORDER BY dm.created_at ASC`,
      [
        dispute.id,
        isAdmin(req),
        String(dispute.assigned_to_id || '') === String(req.auth.uid),
      ],
    );
    return success(res, result.rows);
  }));

  router.post('/analytics/property-view', asyncHandler(async (req, res) => {
    await query(
      `INSERT INTO property_views (
          property_id, user_id, session_id, ip_address, user_agent, referrer, view_duration_seconds
       )
       VALUES (
         (SELECT id FROM properties WHERE uuid = $1),
         $2, $3, $4, $5, $6, $7
       )`,
      [
        req.body?.property_id ?? null,
        req.auth?.uid ?? null,
        req.body?.session_id ?? null,
        req.ip,
        req.headers['user-agent'] ?? null,
        req.headers.referer ?? null,
        req.body?.view_duration_seconds ?? null,
      ],
    );
    return success(res, { recorded: true }, undefined, 201);
  }));

  router.post('/analytics/search', asyncHandler(async (req, res) => {
    await query(
      `INSERT INTO search_analytics (
          user_id, session_id, search_query, filters_applied, result_count, clicked_property_id, click_position
       )
       VALUES (
         $1, $2, $3, COALESCE($4, '{}'::jsonb), COALESCE($5, 0),
         (SELECT id FROM properties WHERE uuid = $6), $7
       )`,
      [
        req.auth?.uid ?? null,
        req.body?.session_id ?? null,
        req.body?.search_query ?? null,
        JSON.stringify(req.body?.filters_applied ?? {}),
        req.body?.result_count ?? 0,
        req.body?.clicked_property_id ?? null,
        req.body?.click_position ?? null,
      ],
    );
    return success(res, { recorded: true }, undefined, 201);
  }));

  const admin = express.Router();
  admin.use(requireAuth, requireRole('admin', 'super_admin'));

  admin.get('/properties/pending', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT uuid AS id, title, property_status, verification_status, created_at
       FROM properties
       WHERE property_status = 'pending'
       ORDER BY created_at DESC`,
    );
    return success(res, result.rows);
  }));

  admin.post('/properties/:id/approve', asyncHandler(async (req, res) => {
    await query(
      `UPDATE properties
       SET property_status = 'active', verification_status = 'verified', updated_at = now()
       WHERE uuid = $1`,
      [req.params.id],
    );
    return success(res, { approved: true, property_id: req.params.id });
  }));

  admin.post('/properties/:id/reject', asyncHandler(async (req, res) => {
    await query(
      `UPDATE properties
       SET property_status = 'rejected', verification_status = 'rejected', updated_at = now()
       WHERE uuid = $1`,
      [req.params.id],
    );
    return success(res, { rejected: true, property_id: req.params.id });
  }));

  admin.get('/kyc/pending', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT
          CONCAT('provider:', k.id) AS id,
          k.id AS numeric_id,
          'provider_case' AS record_type,
          k.provider,
          CASE
            WHEN k.provider = 'sumsub' THEN 'Sumsub live verification'
            ELSE 'Provider verification'
          END AS title,
          k.level_name AS reference,
          k.verification_status::text AS verification_status,
          COALESCE(k.moderation_comment, k.client_comment, '') AS latest_note,
          k.row_version,
          k.created_at
       FROM kyc_provider_cases k
       WHERE k.verification_status = 'pending'
       ORDER BY k.created_at DESC`,
    );
    return success(res, result.rows);
  }));

  admin.get('/kyc/reviews', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, document_id, status, priority, assigned_to, created_at
       FROM kyc_review_tasks
       ORDER BY created_at DESC`,
    );
    return success(res, result.rows);
  }));

  admin.get('/kyc/dashboard', asyncHandler(async (req, res) => {
    const [pendingProviderCases, reviewTasks] = await Promise.all([
      query(`SELECT COUNT(*)::int AS count FROM kyc_provider_cases WHERE verification_status = 'pending'`),
      query(`SELECT COUNT(*)::int AS count FROM kyc_review_tasks WHERE status <> 'resolved'`),
    ]);
    return success(res, {
      pending_documents: pendingProviderCases.rows[0]?.count ?? 0,
      open_review_tasks: reviewTasks.rows[0]?.count ?? 0,
    });
  }));

  admin.get('/kyc/provider-cases/:id', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT
          k.id,
          k.provider,
          k.external_user_id,
          k.provider_applicant_id,
          k.inspection_id,
          k.level_name,
          k.verification_status::text AS verification_status,
          k.provider_review_status,
          k.provider_review_answer,
          k.provider_review_reject_type,
          k.latest_event_type,
          k.moderation_comment,
          k.client_comment,
          k.rejection_labels,
          k.provider_metadata,
          k.access_token_expires_at,
          k.started_at,
          k.last_event_at,
          k.verified_at,
          k.row_version,
          k.created_at,
          k.updated_at,
          u.uuid AS user_uuid,
          u.email AS user_email,
          u.first_name,
          u.last_name
       FROM kyc_provider_cases k
       JOIN users u ON u.id = k.user_id
       WHERE k.id = $1
       LIMIT 1`,
      [req.params.id],
    );
    if (!result.rows[0]) {
      throw notFound('Provider KYC case was not found.');
    }
    return success(res, result.rows[0]);
  }));

  admin.get('/kyc/provider-cases/:id/events', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT
          id,
          correlation_id,
          event_type,
          applicant_id,
          inspection_id,
          external_user_id,
          review_status,
          review_answer,
          review_reject_type,
          payload,
          received_at
       FROM kyc_provider_events
       WHERE provider_case_id = $1
       ORDER BY received_at DESC
       LIMIT 50`,
      [req.params.id],
    );
    return success(res, result.rows);
  }));

  admin.post('/kyc/provider-cases/:id/refresh', asyncHandler(async (req, res) => {
    const refreshedCase = await refreshSumsubCaseById(req.params.id);
    return success(res, {
      refreshed: true,
      provider_case: refreshedCase,
    });
  }));

  admin.post('/kyc/reviews/:id/assign', asyncHandler(async (req, res) => {
    await query(
      `UPDATE kyc_review_tasks
       SET assigned_to = (SELECT id FROM users WHERE uuid = $2), status = 'in_review', updated_at = now()
       WHERE id = $1`,
      [req.params.id, req.body?.reviewer_id],
    );
    return success(res, { assigned: true, review_task_id: Number(req.params.id) });
  }));

  admin.post('/kyc/reviews/:id/resolve', asyncHandler(async (req, res) => {
    await query(
      `UPDATE kyc_review_tasks
       SET status = 'resolved', updated_at = now()
       WHERE id = $1`,
      [req.params.id],
    );
    return success(res, { resolved: true, review_task_id: Number(req.params.id), decision: req.body?.decision ?? null });
  }));

  admin.post('/kyc/:id/approve', asyncHandler(async (req, res) => {
    throw badRequest(
      'Manual KYC review has been retired. Review the Sumsub provider case instead.',
    );
  }));

  admin.post('/kyc/:id/reject', asyncHandler(async (req, res) => {
    throw badRequest(
      'Manual KYC review has been retired. Review the Sumsub provider case instead.',
    );
  }));

  admin.post('/kyc/provider-cases/:id/approve', asyncHandler(async (req, res) => {
    const current = await query(
      `SELECT verification_status::text AS verification_status, row_version
       FROM kyc_provider_cases
       WHERE id = $1
       LIMIT 1`,
      [req.params.id],
    );
    if (!current.rows[0]) {
      throw notFound('Provider KYC case was not found.');
    }
    assertOptimisticLock(current.rows[0].row_version ?? 0, req.body?.expected_version);
    assertKycTransition(current.rows[0].verification_status, 'verified');
    await query(
      `UPDATE kyc_provider_cases
       SET verification_status = 'verified',
           provider_review_status = COALESCE(NULLIF(provider_review_status, ''), 'completed'),
           provider_review_answer = 'GREEN',
           provider_review_reject_type = NULL,
           latest_event_type = 'admin_manual_approve',
           moderation_comment = COALESCE(NULLIF($2, ''), moderation_comment),
           verified_at = now(),
           last_event_at = now(),
           row_version = row_version + 1,
           updated_at = now()
       WHERE id = $1
         AND row_version = $3`,
      [
        req.params.id,
        req.body?.note ?? 'Approved by admin review.',
        current.rows[0].row_version ?? 0,
      ],
    );
    await query(
      `INSERT INTO kyc_provider_events (
           provider_case_id,
           provider,
           correlation_id,
           event_type,
           review_status,
           review_answer,
           payload
         )
         VALUES ($1, 'sumsub', $2, 'admin_manual_approve', 'completed', 'GREEN', $3::jsonb)`,
      [
        req.params.id,
        `admin-approve:${req.params.id}:${Date.now()}`,
        JSON.stringify({
          note: req.body?.note ?? 'Approved by admin review.',
          actor_user_id: req.auth.uid,
        }),
      ],
    );
    return success(res, { approved: true, provider_case_id: Number(req.params.id) });
  }));

  admin.post('/kyc/provider-cases/:id/reject', asyncHandler(async (req, res) => {
    const current = await query(
      `SELECT verification_status::text AS verification_status, row_version
       FROM kyc_provider_cases
       WHERE id = $1
       LIMIT 1`,
      [req.params.id],
    );
    if (!current.rows[0]) {
      throw notFound('Provider KYC case was not found.');
    }
    assertOptimisticLock(current.rows[0].row_version ?? 0, req.body?.expected_version);
    assertKycTransition(current.rows[0].verification_status, 'rejected');
    await query(
      `UPDATE kyc_provider_cases
       SET verification_status = 'rejected',
           provider_review_status = 'completed',
           provider_review_answer = 'RED',
           provider_review_reject_type = COALESCE(NULLIF($2, ''), provider_review_reject_type, 'MANUAL_REJECT'),
           latest_event_type = 'admin_manual_reject',
           moderation_comment = COALESCE(NULLIF($3, ''), moderation_comment, 'Rejected by admin review.'),
           verified_at = now(),
           last_event_at = now(),
           row_version = row_version + 1,
           updated_at = now()
       WHERE id = $1
         AND row_version = $4`,
      [
        req.params.id,
        req.body?.reject_type ?? null,
        req.body?.reason ?? 'Rejected by admin review.',
        current.rows[0].row_version ?? 0,
      ],
    );
    await query(
      `INSERT INTO kyc_provider_events (
           provider_case_id,
           provider,
           correlation_id,
           event_type,
           review_status,
           review_answer,
           review_reject_type,
           payload
         )
         VALUES ($1, 'sumsub', $2, 'admin_manual_reject', 'completed', 'RED', NULLIF($3, ''), $4::jsonb)`,
      [
        req.params.id,
        `admin-reject:${req.params.id}:${Date.now()}`,
        req.body?.reject_type ?? null,
        JSON.stringify({
          reason: req.body?.reason ?? 'Rejected by admin review.',
          actor_user_id: req.auth.uid,
        }),
      ],
    );
    return success(res, { rejected: true, provider_case_id: Number(req.params.id) });
  }));

  admin.post('/escrow/:id/approve', asyncHandler(async (req, res) => {
    await query(
      `UPDATE escrow_transactions
       SET approved_by_id = $2, approved_at = now(), status = 'completed'
       WHERE id = $1`,
      [req.params.id, req.auth.uid],
    );
    return success(res, { approved: true, escrow_transaction_id: Number(req.params.id) });
  }));

  admin.get('/escrow/:id/approvals', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, transaction_reference, status, approved_at
       FROM escrow_transactions
       WHERE id = $1`,
      [req.params.id],
    );
    return success(res, result.rows[0] ?? null);
  }));

  admin.get('/escrow/reconciliation', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, account_number, current_balance, total_deposited, total_withdrawn, updated_at
       FROM escrow_accounts
       ORDER BY updated_at DESC`,
    );
    return success(res, result.rows);
  }));

  admin.get('/escrow/reconciliation/dashboard', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT COUNT(*)::int AS account_count,
              COALESCE(SUM(current_balance),0)::numeric AS balance_total
       FROM escrow_accounts`,
    );
    return success(res, result.rows[0] ?? { account_count: 0, balance_total: 0 });
  }));

  admin.get('/fraud/events', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, event_type, severity, reference_type, reference_id, created_at
       FROM fraud_events
       ORDER BY created_at DESC
       LIMIT 100`,
    ).catch(() => ({ rows: [] }));
    return success(res, result.rows);
  }));

  admin.get('/fraud/events/dashboard', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT COALESCE(severity,'unknown') AS severity, COUNT(*)::int AS count
       FROM fraud_events
       GROUP BY severity`,
    ).catch(() => ({ rows: [] }));
    return success(res, { severity_breakdown: result.rows });
  }));

  router.use('/admin', admin);

  router.post('/webhooks/kyc', asyncHandler(async (req, res) => {
    const result = await consumeSumsubWebhook({
      headers: req.headers,
      rawBody: req.rawBody ?? '',
      payload: req.body,
    });
    return success(res, result, undefined, 202);
  }));
  router.post('/webhooks/email', asyncHandler(async (req, res) => success(res, { accepted: true }, undefined, 202)));
  router.post('/webhooks/sms', asyncHandler(async (req, res) => success(res, { accepted: true }, undefined, 202)));

  return router;
}

module.exports = { buildGovernanceRouter };

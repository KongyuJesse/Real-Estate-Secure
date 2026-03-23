const express = require('express');

const { query } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest, notFound } = require('../lib/errors');
const { getPagination } = require('../lib/pagination');
const {
  requireTransactionAccess,
  requireTransactionActor,
} = require('../services/authorization-service');
const { recordAuditEvent } = require('../services/audit-service');
const { withIdempotency } = require('../services/idempotency-service');
const { appendOutboxEvent } = require('../services/outbox-service');
const {
  getAssetRecord,
  parseAssetReference,
  resolveAssetUrlFromReference,
} = require('../services/storage-service');
const {
  assertClosingEvidenceReady,
  assertCompletionReady,
  assertTransactionCreationEligibility,
  loadPropertyForTransaction,
  resolveUserByUuid,
} = require('../services/transaction-validation-service');
const {
  assertClosingStateUpdate,
  assertLegalCaseTransition,
  assertOfflineStepTransition,
  assertOptimisticLock,
  assertTransactionTransition,
} = require('../services/workflow-service');

async function resolveAssetIdFromReference(reference) {
  const assetUuid = parseAssetReference(reference);
  if (!assetUuid) {
    return null;
  }
  const result = await query('SELECT id FROM uploaded_assets WHERE uuid = $1 LIMIT 1', [assetUuid]);
  return result.rows[0]?.id ?? null;
}

async function assertOwnedTransactionAsset(reference, ownerUserId) {
  const assetUuid = parseAssetReference(reference);
  if (!assetUuid) {
    throw badRequest('Asset reference is invalid.');
  }
  const asset = await getAssetRecord(assetUuid);
  if (!asset) {
    throw notFound('Uploaded asset not found.');
  }
  if (String(asset.owner_user_id || '') !== String(ownerUserId)) {
    throw badRequest('Uploaded assets must belong to the current user.');
  }
  if (String(asset.category) !== 'transaction_document') {
    throw badRequest('Only transaction document uploads can be attached to a transaction.');
  }
  if (String(asset.malware_scan_status) === 'rejected') {
    throw badRequest('Uploaded asset failed security scanning and cannot be attached.');
  }
  return asset;
}

async function serializeTransaction(row) {
  return {
    uuid: row.uuid,
    transaction_number: row.transaction_number,
    transaction_status: row.transaction_status,
    transaction_type: row.transaction_type,
    settlement_mode: row.settlement_mode,
    total_amount: Number(row.total_amount ?? 0),
    currency: row.currency,
    property_id: row.property_uuid,
    buyer_id: row.buyer_uuid ?? row.buyer_id,
    seller_id: row.seller_uuid ?? row.seller_id,
    lawyer_id: row.lawyer_uuid ?? row.lawyer_id,
    notary_id: row.notary_uuid ?? row.notary_id,
    commercial_close_status: row.commercial_close_status,
    notarial_execution_status: row.notarial_execution_status,
    title_confirmation_status: row.title_confirmation_status,
    automation_frozen: row.automation_frozen,
    automation_freeze_reason: row.automation_freeze_reason,
    row_version: row.row_version ?? 0,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

function buildTransactionsRouter() {
  const router = express.Router();

  router.get('/', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT
          t.uuid,
          t.transaction_number,
          t.transaction_status,
          t.total_amount,
          t.currency,
          t.commercial_close_status,
          t.notarial_execution_status,
          t.title_confirmation_status,
          t.created_at
       FROM transactions t
       WHERE t.buyer_id = $1 OR t.seller_id = $1 OR t.lawyer_id = $1 OR t.notary_id = $1
       ORDER BY t.created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.auth.uid, limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/:id', asyncHandler(async (req, res) => {
    const row = await requireTransactionAccess(req, req.params.id);
    return success(res, await serializeTransaction(row));
  }));

  router.get('/:id/compliance', asyncHandler(async (req, res) => {
    const row = await requireTransactionAccess(req, req.params.id, { action: 'read_transaction_compliance' });
    const [steps, cases, docs] = await Promise.all([
      query('SELECT COUNT(*)::int AS count FROM transaction_offline_steps WHERE transaction_id = $1', [row.id]),
      query('SELECT COUNT(*)::int AS count FROM transaction_legal_cases WHERE transaction_id = $1', [row.id]),
      query('SELECT COUNT(*)::int AS count FROM transaction_documents WHERE transaction_id = $1', [row.id]),
    ]);
    return success(res, {
      transaction_id: row.uuid,
      transaction_status: row.transaction_status,
      settlement_mode: row.settlement_mode,
      legal_case_type: row.legal_case_type,
      lawyer_requirement_level: row.lawyer_requirement_level,
      notary_requirement_level: row.notary_requirement_level,
      foreign_party_involved: row.foreign_party_involved,
      automation_frozen: row.automation_frozen,
      automation_freeze_reason: row.automation_freeze_reason,
      offline_workflow_required: row.offline_workflow_required,
      commercial_close_status: row.commercial_close_status,
      notarial_execution_status: row.notarial_execution_status,
      title_confirmation_status: row.title_confirmation_status,
      offline_step_count: steps.rows[0]?.count ?? 0,
      legal_case_count: cases.rows[0]?.count ?? 0,
      document_count: docs.rows[0]?.count ?? 0,
      row_version: row.row_version ?? 0,
    });
  }));

  router.post('/initiate', withIdempotency({ ttlSeconds: 86400 }), asyncHandler(async (req, res) => {
    const {
      property_id,
      seller_id,
      lawyer_id,
      notary_id,
      transaction_type,
      property_price,
      currency = 'XAF',
      legal_case_type = null,
      settlement_mode = 'platform_escrow',
      lawyer_requirement_level = 'recommended',
      notary_requirement_level = 'required',
      foreign_party_involved = false,
      assisted_lane_reason = null,
      offline_workflow_required = false,
    } = req.body ?? {};

    if (!property_id || !seller_id || !transaction_type || !property_price) {
      throw badRequest('property_id, seller_id, transaction_type, and property_price are required.');
    }

    const property = await loadPropertyForTransaction(property_id);
    const sellerUser = await resolveUserByUuid(seller_id, 'Seller');
    if (lawyer_id) {
      await resolveUserByUuid(lawyer_id, 'Lawyer');
    }
    if (notary_id) {
      await resolveUserByUuid(notary_id, 'Notary');
    }
    assertTransactionCreationEligibility({
      property,
      sellerUser,
      buyerUserId: req.auth.uid,
      transactionType: transaction_type,
      propertyPrice: property_price,
      settlementMode: settlement_mode,
      assistedLaneReason: assisted_lane_reason,
      offlineWorkflowRequired,
    });

    const created = await query(
      `INSERT INTO transactions (
          transaction_number,
          property_id,
          buyer_id,
          seller_id,
          lawyer_id,
          notary_id,
          transaction_type,
          transaction_status,
          property_price,
          total_amount,
          currency,
          legal_case_type,
          settlement_mode,
          lawyer_requirement_level,
          notary_requirement_level,
          foreign_party_involved,
          assisted_lane_reason,
          offline_workflow_required,
          commercial_close_status,
          notarial_execution_status,
          title_confirmation_status
       )
       VALUES (
         CONCAT('TRX-', TO_CHAR(now(), 'YYYYMMDDHH24MISS'), '-', FLOOR(random() * 100000)::int),
         (SELECT id FROM properties WHERE uuid = $1),
         $2,
         (SELECT id FROM users WHERE uuid = $3),
         (SELECT id FROM users WHERE uuid = $4),
         (SELECT id FROM users WHERE uuid = $5),
         $6,
         'initiated',
         $7,
         $7,
         $8,
         $9,
         $10,
         $11,
         $12,
         $13,
         $14,
         $15,
         'open',
         'pending',
         'pending'
       )
       RETURNING uuid, transaction_number, transaction_status, total_amount, currency, created_at`,
      [
        property_id,
        req.auth.uid,
        seller_id,
        lawyer_id ?? null,
        notary_id ?? null,
        transaction_type,
        property_price,
        currency,
        legal_case_type ?? (property?.listing_type === 'sale' ? 'standard_sale' : transaction_type),
        settlement_mode,
        lawyer_requirement_level,
        notary_requirement_level,
        foreign_party_involved,
        assisted_lane_reason,
        offline_workflow_required,
      ],
    );

    await appendOutboxEvent({
      topic: 'transaction.created',
      aggregateType: 'transaction',
      aggregateId: created.rows[0].uuid,
      eventKey: `transaction.created:${created.rows[0].uuid}:${req.requestId}`,
      payload: {
        transaction_uuid: created.rows[0].uuid,
        property_uuid: property_id,
        seller_uuid: seller_id,
      },
    });

    return success(res, created.rows[0], undefined, 201);
  }));

  for (const [path, status, allowedActors] of [
    ['/:id/deposit', 'deposited', ['buyer']],
    ['/:id/inspect', 'inspection_period', ['buyer', 'lawyer', 'notary']],
    ['/:id/approve', 'completed', ['lawyer', 'notary']],
    ['/:id/release', 'completed', ['notary', 'lawyer']],
    ['/:id/hold', 'disputed', ['buyer', 'seller', 'lawyer', 'notary']],
    ['/:id/refund', 'refunded', ['lawyer', 'notary']],
    ['/:id/cancel', 'cancelled', ['buyer', 'seller', 'lawyer', 'notary']],
  ]) {
    router.post(path, withIdempotency(), asyncHandler(async (req, res) => {
      const transaction = await requireTransactionAccess(req, req.params.id, { action: 'write_transaction' });
      const actor = await requireTransactionActor(req, transaction, allowedActors);
      assertOptimisticLock(transaction.row_version ?? 0, req.body?.expected_version);
      assertTransactionTransition(transaction.transaction_status, status, actor);
      if (status === 'completed') {
        assertCompletionReady(transaction);
      }

      const updated = await query(
        `UPDATE transactions
         SET transaction_status = $2,
             row_version = row_version + 1,
             updated_at = now()
         WHERE uuid = $1
           AND row_version = $3
         RETURNING uuid, transaction_status, row_version`,
        [req.params.id, status, transaction.row_version ?? 0],
      );
      if (!updated.rows[0]) {
        throw notFound('Transaction not found.');
      }

      await recordAuditEvent({
        req,
        userId: req.auth.uid,
        action: `transaction_status_${status}`,
        entityType: 'transaction',
        entityId: transaction.id,
        oldValues: { transaction_status: transaction.transaction_status },
        newValues: { transaction_status: status },
      });
      await appendOutboxEvent({
        topic: 'transaction.status_changed',
        aggregateType: 'transaction',
        aggregateId: req.params.id,
        eventKey: `transaction.status_changed:${req.params.id}:${status}:${req.requestId}`,
        payload: {
          transaction_uuid: req.params.id,
          actor,
          status,
        },
      });

      return success(res, updated.rows[0]);
    }));
  }

  router.post('/:id/lawyer', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'assign_transaction_lawyer' });
    await requireTransactionActor(req, transaction, ['buyer', 'seller']);
    assertOptimisticLock(transaction.row_version ?? 0, req.body?.expected_version);
    const updated = await query(
      `UPDATE transactions
       SET lawyer_id = (SELECT id FROM users WHERE uuid = $2),
           row_version = row_version + 1,
           updated_at = now()
       WHERE uuid = $1
         AND row_version = $3
       RETURNING uuid, lawyer_id, row_version`,
      [req.params.id, req.body?.lawyer_id, transaction.row_version ?? 0],
    );
    if (!updated.rows[0]) {
      throw notFound('Transaction not found.');
    }
    await appendOutboxEvent({
      topic: 'transaction.lawyer_assigned',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.lawyer_assigned:${req.params.id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        lawyer_uuid: req.body?.lawyer_id ?? null,
      },
    });
    return success(res, updated.rows[0]);
  }));

  router.post('/:id/notary', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'assign_transaction_notary' });
    await requireTransactionActor(req, transaction, ['buyer', 'seller']);
    assertOptimisticLock(transaction.row_version ?? 0, req.body?.expected_version);
    const updated = await query(
      `UPDATE transactions
       SET notary_id = (SELECT id FROM users WHERE uuid = $2),
           row_version = row_version + 1,
           updated_at = now()
       WHERE uuid = $1
         AND row_version = $3
       RETURNING uuid, notary_id, row_version`,
      [req.params.id, req.body?.notary_id, transaction.row_version ?? 0],
    );
    if (!updated.rows[0]) {
      throw notFound('Transaction not found.');
    }
    await appendOutboxEvent({
      topic: 'transaction.notary_assigned',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.notary_assigned:${req.params.id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        notary_uuid: req.body?.notary_id ?? null,
      },
    });
    return success(res, updated.rows[0]);
  }));

  router.post('/:id/closing-stage', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'update_transaction_closing_states' });
    const actor = await requireTransactionActor(req, transaction, ['lawyer', 'notary']);
    const payload = req.body ?? {};
    assertOptimisticLock(transaction.row_version ?? 0, payload.expected_version);
    if (payload.transaction_status) {
      assertTransactionTransition(transaction.transaction_status, payload.transaction_status, actor);
    }
    if (transaction.automation_frozen && payload.automation_frozen !== false) {
      throw badRequest('This transaction is automation-frozen and cannot advance until the blocker is cleared.');
    }
    assertClosingStateUpdate(transaction.commercial_close_status, payload.commercial_close_status, 'commercial_close_status');
    assertClosingStateUpdate(transaction.notarial_execution_status, payload.notarial_execution_status, 'notarial_execution_status');
    assertClosingStateUpdate(transaction.title_confirmation_status, payload.title_confirmation_status, 'title_confirmation_status');
    await assertClosingEvidenceReady(transaction, payload);

    const updated = await query(
      `UPDATE transactions
       SET transaction_status = COALESCE($2, transaction_status),
           commercial_close_status = COALESCE($3, commercial_close_status),
           notarial_execution_status = COALESCE($4, notarial_execution_status),
           title_confirmation_status = COALESCE($5, title_confirmation_status),
           automation_frozen = COALESCE($6, automation_frozen),
           automation_freeze_reason = COALESCE($7, automation_freeze_reason),
           row_version = row_version + 1,
           updated_at = now()
       WHERE uuid = $1
         AND row_version = $8
       RETURNING uuid, transaction_status, commercial_close_status, notarial_execution_status,
                 title_confirmation_status, automation_frozen, automation_freeze_reason, row_version`,
      [
        req.params.id,
        payload.transaction_status ?? null,
        payload.commercial_close_status ?? null,
        payload.notarial_execution_status ?? null,
        payload.title_confirmation_status ?? null,
        payload.automation_frozen ?? null,
        payload.automation_freeze_reason ?? null,
        transaction.row_version ?? 0,
      ],
    );
    if (!updated.rows[0]) {
      throw notFound('Transaction not found.');
    }
    await appendOutboxEvent({
      topic: 'transaction.closing_stage_updated',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.closing_stage_updated:${req.params.id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        transaction_status: updated.rows[0].transaction_status,
        commercial_close_status: updated.rows[0].commercial_close_status,
        notarial_execution_status: updated.rows[0].notarial_execution_status,
        title_confirmation_status: updated.rows[0].title_confirmation_status,
      },
    });
    return success(res, updated.rows[0]);
  }));

  router.post('/:id/documents', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'upload_transaction_document' });
    await requireTransactionActor(req, transaction, ['buyer', 'seller', 'lawyer', 'notary']);
    const {
      document_type,
      file_path,
      mime_type,
      file_hash,
      file_size,
      verification_status = 'pending',
      notes,
      original_seen_at,
      certified_copy_verified = false,
      seen_at_location,
      issuing_office,
    } = req.body ?? {};

    if (!document_type || !file_path) {
      throw badRequest('document_type and file_path are required.');
    }

    await assertOwnedTransactionAsset(file_path, req.auth.uid);
    const assetId = await resolveAssetIdFromReference(file_path);
    const inserted = await query(
      `INSERT INTO transaction_documents (
          transaction_id, document_type, file_path, file_hash, file_size, mime_type,
          uploaded_by, verification_status, notes, original_seen_by, original_seen_at,
          certified_copy_verified, seen_at_location, issuing_office, asset_id
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$7,$10,$11,$12,$13,$14)
       RETURNING id, document_type, verification_status, created_at`,
      [
        transaction.id,
        document_type,
        file_path,
        file_hash ?? null,
        file_size ?? null,
        mime_type ?? null,
        req.auth.uid,
        verification_status,
        notes ?? null,
        original_seen_at ?? null,
        certified_copy_verified,
        seen_at_location ?? null,
        issuing_office ?? null,
        assetId,
      ],
    );
    await appendOutboxEvent({
      topic: 'transaction.document_added',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.document_added:${req.params.id}:${inserted.rows[0].id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        document_id: inserted.rows[0].id,
        document_type,
      },
    });
    return success(res, inserted.rows[0], undefined, 201);
  }));

  router.get('/:id/offline-steps', asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'read_transaction_offline_steps' });
    const result = await query(
      `SELECT uuid AS id, step_type, physical_status, expected_office, assigned_role, notes,
              delay_reason, original_required, oversight_required, filing_date,
              scheduled_at, next_follow_up_date, completed_at, row_version
       FROM transaction_offline_steps
       WHERE transaction_id = $1
       ORDER BY created_at DESC`,
      [transaction.id],
    );
    return success(res, result.rows);
  }));

  router.post('/:id/offline-steps', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'create_transaction_offline_step' });
    await requireTransactionActor(req, transaction, ['lawyer', 'notary']);
    const payload = req.body ?? {};
    if (!payload.step_type || !payload.physical_status) {
      throw badRequest('step_type and physical_status are required.');
    }
    const inserted = await query(
      `INSERT INTO transaction_offline_steps (
          transaction_id, property_id, step_type, physical_status, expected_office,
          assigned_role, filing_date, scheduled_at, next_follow_up_date,
          original_required, oversight_required, notes, created_by, updated_by
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$13)
       RETURNING uuid AS id, step_type, physical_status, expected_office, assigned_role, notes,
                 delay_reason, original_required, oversight_required, filing_date, scheduled_at,
                 next_follow_up_date, completed_at, row_version`,
      [
        transaction.id,
        transaction.property_id,
        payload.step_type,
        payload.physical_status,
        payload.expected_office ?? null,
        payload.assigned_role ?? null,
        payload.filing_date ?? null,
        payload.scheduled_at ?? null,
        payload.next_follow_up_date ?? null,
        payload.original_required === true,
        payload.oversight_required === true,
        payload.notes ?? null,
        req.auth.uid,
      ],
    );
    await appendOutboxEvent({
      topic: 'transaction.offline_step_created',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.offline_step_created:${req.params.id}:${inserted.rows[0].id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        step_id: inserted.rows[0].id,
        step_type: payload.step_type,
      },
    });
    return success(res, inserted.rows[0], undefined, 201);
  }));

  router.post('/:id/offline-steps/:stepId/status', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'update_transaction_offline_step' });
    await requireTransactionActor(req, transaction, ['lawyer', 'notary']);
    const payload = req.body ?? {};
    const current = await query(
      `SELECT *
       FROM transaction_offline_steps
       WHERE transaction_id = $1 AND uuid = $2
       LIMIT 1`,
      [transaction.id, req.params.stepId],
    );
    const step = current.rows[0];
    if (!step) {
      throw notFound('Offline step not found.');
    }
    assertOptimisticLock(step.row_version ?? 0, payload.expected_version);
    assertOfflineStepTransition(step.physical_status, payload.physical_status);
    const updated = await query(
      `UPDATE transaction_offline_steps
       SET physical_status = COALESCE($3, physical_status),
           delay_reason = COALESCE($4, delay_reason),
           notes = COALESCE($5, notes),
           filing_date = COALESCE($6, filing_date),
           scheduled_at = COALESCE($7, scheduled_at),
           next_follow_up_date = COALESCE($8, next_follow_up_date),
           completed_at = CASE WHEN COALESCE($3, physical_status) = 'completed' THEN now() ELSE completed_at END,
           row_version = row_version + 1,
           updated_by = $9,
           updated_at = now()
       WHERE transaction_id = $1
         AND uuid = $2
         AND row_version = $10
       RETURNING uuid AS id, step_type, physical_status, expected_office, assigned_role, notes,
                 delay_reason, original_required, oversight_required, filing_date, scheduled_at,
                 next_follow_up_date, completed_at, row_version`,
      [
        transaction.id,
        req.params.stepId,
        payload.physical_status ?? null,
        payload.delay_reason ?? null,
        payload.notes ?? null,
        payload.filing_date ?? null,
        payload.scheduled_at ?? null,
        payload.next_follow_up_date ?? null,
        req.auth.uid,
        step.row_version ?? 0,
      ],
    );
    if (!updated.rows[0]) {
      throw notFound('Offline step not found.');
    }
    await appendOutboxEvent({
      topic: 'transaction.offline_step_updated',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.offline_step_updated:${req.params.id}:${req.params.stepId}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        step_id: req.params.stepId,
        status: updated.rows[0].physical_status,
      },
    });
    return success(res, updated.rows[0]);
  }));

  router.get('/:id/legal-cases', asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'read_transaction_legal_cases' });
    const result = await query(
      `SELECT uuid AS id, case_type, status, freezes_automation, requires_admin_oversight,
              expected_office, reference_number, court_name, notes, delay_reason,
              filing_date, next_follow_up_date, final_decision_date, row_version
       FROM transaction_legal_cases
       WHERE transaction_id = $1
       ORDER BY created_at DESC`,
      [transaction.id],
    );
    return success(res, result.rows);
  }));

  router.post('/:id/legal-cases', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'create_transaction_legal_case' });
    await requireTransactionActor(req, transaction, ['lawyer', 'notary']);
    const payload = req.body ?? {};
    if (!payload.case_type) {
      throw badRequest('case_type is required.');
    }
    const inserted = await query(
      `INSERT INTO transaction_legal_cases (
          transaction_id, property_id, case_type, status, freezes_automation,
          requires_admin_oversight, expected_office, reference_number, court_name,
          filing_date, next_follow_up_date, final_decision_date, delay_reason,
          notes, created_by, updated_by
       )
       VALUES ($1,$2,$3,COALESCE($4,'pending_filing'),COALESCE($5,true),COALESCE($6,false),
               $7,$8,$9,$10,$11,$12,$13,$14,$15,$15)
       RETURNING uuid AS id, case_type, status, freezes_automation, requires_admin_oversight,
                 expected_office, reference_number, court_name, notes, delay_reason,
                 filing_date, next_follow_up_date, final_decision_date, row_version`,
      [
        transaction.id,
        transaction.property_id,
        payload.case_type,
        payload.status ?? null,
        payload.freezes_automation ?? null,
        payload.requires_admin_oversight ?? null,
        payload.expected_office ?? null,
        payload.reference_number ?? null,
        payload.court_name ?? null,
        payload.filing_date ?? null,
        payload.next_follow_up_date ?? null,
        payload.final_decision_date ?? null,
        payload.delay_reason ?? null,
        payload.notes ?? null,
        req.auth.uid,
      ],
    );
    await appendOutboxEvent({
      topic: 'transaction.legal_case_created',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.legal_case_created:${req.params.id}:${inserted.rows[0].id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        case_id: inserted.rows[0].id,
        case_type: payload.case_type,
      },
    });
    return success(res, inserted.rows[0], undefined, 201);
  }));

  router.post('/:id/legal-cases/:caseId/status', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'update_transaction_legal_case' });
    await requireTransactionActor(req, transaction, ['lawyer', 'notary']);
    const payload = req.body ?? {};
    const current = await query(
      `SELECT *
       FROM transaction_legal_cases
       WHERE transaction_id = $1 AND uuid = $2
       LIMIT 1`,
      [transaction.id, req.params.caseId],
    );
    const legalCase = current.rows[0];
    if (!legalCase) {
      throw notFound('Legal case not found.');
    }
    assertOptimisticLock(legalCase.row_version ?? 0, payload.expected_version);
    assertLegalCaseTransition(legalCase.status, payload.status);
    const updated = await query(
      `UPDATE transaction_legal_cases
       SET status = COALESCE($3, status),
           delay_reason = COALESCE($4, delay_reason),
           notes = COALESCE($5, notes),
           reference_number = COALESCE($6, reference_number),
           court_name = COALESCE($7, court_name),
           expected_office = COALESCE($8, expected_office),
           filing_date = COALESCE($9, filing_date),
           next_follow_up_date = COALESCE($10, next_follow_up_date),
           final_decision_date = COALESCE($11, final_decision_date),
           row_version = row_version + 1,
           updated_by = $12,
           updated_at = now()
       WHERE transaction_id = $1
         AND uuid = $2
         AND row_version = $13
       RETURNING uuid AS id, case_type, status, freezes_automation, requires_admin_oversight,
                 expected_office, reference_number, court_name, notes, delay_reason,
                 filing_date, next_follow_up_date, final_decision_date, row_version`,
      [
        transaction.id,
        req.params.caseId,
        payload.status ?? null,
        payload.delay_reason ?? null,
        payload.notes ?? null,
        payload.reference_number ?? null,
        payload.court_name ?? null,
        payload.expected_office ?? null,
        payload.filing_date ?? null,
        payload.next_follow_up_date ?? null,
        payload.final_decision_date ?? null,
        req.auth.uid,
        legalCase.row_version ?? 0,
      ],
    );
    if (!updated.rows[0]) {
      throw notFound('Legal case not found.');
    }
    await appendOutboxEvent({
      topic: 'transaction.legal_case_updated',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.legal_case_updated:${req.params.id}:${req.params.caseId}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        case_id: req.params.caseId,
        status: updated.rows[0].status,
      },
    });
    return success(res, updated.rows[0]);
  }));

  router.get('/:id/declarations', asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'read_transaction_declarations' });
    const result = await query(
      `SELECT uuid AS id, settlement_mode, payment_channel, amount, currency, status, occurred_at, notes
       FROM transaction_settlement_declarations
       WHERE transaction_id = $1
       ORDER BY created_at DESC`,
      [transaction.id],
    );
    return success(res, result.rows);
  }));

  router.post('/:id/declarations', withIdempotency({ ttlSeconds: 86400 }), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'create_transaction_declaration' });
    await requireTransactionActor(req, transaction, ['buyer', 'seller']);
    const payload = req.body ?? {};
    if (!payload.settlement_mode || !payload.payment_channel || !payload.amount || !payload.occurred_at) {
      throw badRequest('settlement_mode, payment_channel, amount, and occurred_at are required.');
    }

    const inserted = await query(
      `INSERT INTO transaction_settlement_declarations (
          transaction_id, declared_by_id, settlement_mode, payment_channel, amount,
          currency, payment_reference, provider_name, occurred_at, notes, evidence
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,COALESCE($11,'{}'::jsonb))
       RETURNING uuid AS id, status`,
      [
        transaction.id,
        req.auth.uid,
        payload.settlement_mode,
        payload.payment_channel,
        payload.amount,
        payload.currency ?? 'XAF',
        payload.payment_reference ?? null,
        payload.provider_name ?? null,
        payload.occurred_at,
        payload.notes ?? null,
        JSON.stringify(payload.evidence ?? {}),
      ],
    );
    await appendOutboxEvent({
      topic: 'transaction.declaration_created',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.declaration_created:${req.params.id}:${inserted.rows[0].id}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        declaration_id: inserted.rows[0].id,
        settlement_mode: payload.settlement_mode,
      },
    });
    return success(res, inserted.rows[0], undefined, 201);
  }));

  router.post('/:id/declarations/:declarationId/confirm', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'confirm_transaction_declaration' });
    await requireTransactionActor(req, transaction, ['buyer', 'seller']);
    await query(
      `INSERT INTO transaction_settlement_confirmations (declaration_id, user_id, status, note, confirmed_at)
       VALUES (
         (SELECT id FROM transaction_settlement_declarations WHERE uuid = $1),
         $2,
         COALESCE($3, 'confirmed'),
         $4,
         now()
       )
       ON CONFLICT (declaration_id, user_id)
       DO UPDATE SET status = EXCLUDED.status, note = EXCLUDED.note, confirmed_at = now(), updated_at = now()`,
      [req.params.declarationId, req.auth.uid, req.body?.status ?? null, req.body?.note ?? null],
    );
    await appendOutboxEvent({
      topic: 'transaction.declaration_confirmed',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.declaration_confirmed:${req.params.id}:${req.params.declarationId}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        declaration_id: req.params.declarationId,
        confirmer_user_id: req.auth.uid,
      },
    });
    return success(res, { confirmed: true });
  }));

  router.post('/:id/declarations/:declarationId/review', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'review_transaction_declaration' });
    await requireTransactionActor(req, transaction, ['lawyer', 'notary']);
    await query(
      `UPDATE transaction_settlement_declarations
       SET status = COALESCE($2, status),
           reviewed_by_id = $3,
           reviewed_at = now(),
           review_notes = $4,
           updated_at = now()
       WHERE uuid = $1`,
      [req.params.declarationId, req.body?.status ?? null, req.auth.uid, req.body?.review_notes ?? null],
    );
    await appendOutboxEvent({
      topic: 'transaction.declaration_reviewed',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.declaration_reviewed:${req.params.id}:${req.params.declarationId}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        declaration_id: req.params.declarationId,
        reviewer_user_id: req.auth.uid,
        status: req.body?.status ?? null,
      },
    });
    return success(res, { reviewed: true });
  }));

  router.post('/:id/dispute', withIdempotency(), asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'create_transaction_dispute' });
    await requireTransactionActor(req, transaction, ['buyer', 'seller', 'lawyer', 'notary']);
    const payload = req.body ?? {};
    const inserted = await query(
      `INSERT INTO disputes (
          dispute_number, transaction_id, raised_by_id, raised_against_id, dispute_type,
          description, requested_resolution, priority
       )
       VALUES (
         CONCAT('DSP-', TO_CHAR(now(), 'YYYYMMDDHH24MISS'), '-', FLOOR(random() * 100000)::int),
         $1,$2,$3,COALESCE($4,'other'),$5,$6,COALESCE($7,'medium')
       )
       RETURNING dispute_number, status`,
      [
        transaction.id,
        req.auth.uid,
        payload.raised_against_id ?? null,
        payload.dispute_type ?? null,
        payload.description ?? 'Dispute created from transaction workflow.',
        payload.requested_resolution ?? 'Review requested.',
        payload.priority ?? null,
      ],
    );
    await appendOutboxEvent({
      topic: 'transaction.dispute_created',
      aggregateType: 'transaction',
      aggregateId: req.params.id,
      eventKey: `transaction.dispute_created:${req.params.id}:${inserted.rows[0].dispute_number}:${req.requestId}`,
      payload: {
        transaction_uuid: req.params.id,
        dispute_number: inserted.rows[0].dispute_number,
      },
    });
    return success(res, inserted.rows[0], undefined, 201);
  }));

  router.get('/:id/timeline', asyncHandler(async (req, res) => {
    const transaction = await requireTransactionAccess(req, req.params.id, { action: 'read_transaction_timeline' });
    const events = [
      {
        type: 'transaction',
        status: transaction.transaction_status,
        commercial_close_status: transaction.commercial_close_status,
        notarial_execution_status: transaction.notarial_execution_status,
        title_confirmation_status: transaction.title_confirmation_status,
        created_at: transaction.created_at,
      },
    ];

    const [steps, cases, docs] = await Promise.all([
      query(
        `SELECT step_type AS label, physical_status AS status, created_at
         FROM transaction_offline_steps
         WHERE transaction_id = $1`,
        [transaction.id],
      ),
      query(
        `SELECT case_type AS label, status, created_at
         FROM transaction_legal_cases
         WHERE transaction_id = $1`,
        [transaction.id],
      ),
      query(
        `SELECT document_type AS label, verification_status AS status, file_path, created_at
         FROM transaction_documents
         WHERE transaction_id = $1`,
        [transaction.id],
      ),
    ]);

    steps.rows.forEach((row) => events.push({ type: 'offline_step', ...row }));
    cases.rows.forEach((row) => events.push({ type: 'legal_case', ...row }));
    await Promise.all(
      docs.rows.map(async (row) => {
        events.push({
          type: 'document',
          label: row.label,
          status: row.status,
          file_path: await resolveAssetUrlFromReference(row.file_path, req),
          created_at: row.created_at,
        });
      }),
    );

    events.sort((left, right) => new Date(right.created_at) - new Date(left.created_at));
    return success(res, events);
  }));

  return router;
}

module.exports = { buildTransactionsRouter };

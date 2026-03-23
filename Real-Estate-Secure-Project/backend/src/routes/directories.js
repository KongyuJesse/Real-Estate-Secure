const express = require('express');

const { query } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { notFound } = require('../lib/errors');
const { requireAuth } = require('../middleware/auth');
const { getPagination } = require('../lib/pagination');

function buildDirectoriesRouter() {
  const router = express.Router();

  router.get('/lawyers', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT lp.id, u.uuid, u.first_name, u.last_name, lp.bar_number, lp.law_firm_name,
              lp.consultation_fee, lp.average_rating, lp.verification_status
       FROM lawyer_profiles lp
       JOIN users u ON u.id = lp.user_id
       ORDER BY lp.average_rating DESC, lp.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/lawyers/pending', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, transaction_id, decision, created_at
       FROM transaction_legal_reviews
       WHERE reviewer_id = $1
       ORDER BY created_at DESC`,
      [req.auth.uid],
    );
    return success(res, result.rows);
  }));

  router.get('/lawyers/:id', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT u.uuid, u.first_name, u.last_name, u.email, lp.*
       FROM lawyer_profiles lp
       JOIN users u ON u.id = lp.user_id
       WHERE u.uuid = $1
       LIMIT 1`,
      [req.params.id],
    );
    if (!result.rows[0]) {
      throw notFound('Lawyer not found.');
    }
    return success(res, result.rows[0]);
  }));

  router.get('/lawyers/:id/reviews', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT lr.rating, lr.title, lr.review_text, lr.created_at
       FROM lawyer_reviews lr
       JOIN lawyer_profiles lp ON lp.id = lr.lawyer_id
       JOIN users u ON u.id = lp.user_id
       WHERE u.uuid = $1
       ORDER BY lr.created_at DESC`,
      [req.params.id],
    );
    return success(res, result.rows);
  }));

  router.post('/lawyers/:id/hire', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE transactions
       SET lawyer_id = (SELECT id FROM users WHERE uuid = $2), updated_at = now()
       WHERE uuid = $1`,
      [req.body?.transaction_id, req.params.id],
    );
    return success(res, { hired: true, lawyer_id: req.params.id });
  }));

  router.post('/lawyers/verify/:documentId', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE property_documents
       SET is_verified = true, verified_by = $2, verified_at = now(), verification_notes = $3
       WHERE id = $1`,
      [req.params.documentId, req.auth.uid, req.body?.notes ?? null],
    );
    return success(res, { verified: true, document_id: req.params.documentId });
  }));

  router.post('/lawyers/reject/:documentId', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE property_documents
       SET is_verified = false, rejection_reason = $3, verified_by = $2, verified_at = now()
       WHERE id = $1`,
      [req.params.documentId, req.auth.uid, req.body?.reason ?? 'Rejected by legal review.'],
    );
    return success(res, { rejected: true, document_id: req.params.documentId });
  }));

  router.post('/lawyers/review/:transactionId', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `INSERT INTO transaction_legal_reviews (transaction_id, reviewer_id, decision, notes)
       VALUES ((SELECT id FROM transactions WHERE uuid = $1), $2, $3, $4)
       RETURNING id, decision, created_at`,
      [req.params.transactionId, req.auth.uid, req.body?.decision ?? 'approved', req.body?.notes ?? null],
    );
    return success(res, result.rows[0], undefined, 201);
  }));

  router.get('/notaries', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT np.id, u.uuid, u.first_name, u.last_name, np.office_name, np.appointment_number,
              np.consultation_fee, np.verification_status
       FROM notary_profiles np
       JOIN users u ON u.id = np.user_id
       ORDER BY np.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/notaries/:id', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT u.uuid, u.first_name, u.last_name, u.email, np.*
       FROM notary_profiles np
       JOIN users u ON u.id = np.user_id
       WHERE u.uuid = $1
       LIMIT 1`,
      [req.params.id],
    );
    if (!result.rows[0]) {
      throw notFound('Notary not found.');
    }
    return success(res, result.rows[0]);
  }));

  router.post('/notaries/:id/hire', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE transactions
       SET notary_id = (SELECT id FROM users WHERE uuid = $2), updated_at = now()
       WHERE uuid = $1`,
      [req.body?.transaction_id, req.params.id],
    );
    return success(res, { hired: true, notary_id: req.params.id });
  }));

  return router;
}

module.exports = { buildDirectoriesRouter };

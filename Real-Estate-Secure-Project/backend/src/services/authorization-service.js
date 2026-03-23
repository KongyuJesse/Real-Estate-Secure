const { query } = require('../db');
const { forbidden, notFound } = require('../lib/errors');
const { recordPrivilegedRead } = require('./audit-service');

function hasRole(req, ...roles) {
  const current = Array.isArray(req.auth?.roles) ? req.auth.roles : [];
  return current.some((role) => roles.includes(role));
}

function isAdmin(req) {
  return hasRole(req, 'admin', 'super_admin');
}

async function requireTransactionAccess(req, transactionUuid, { action = 'read_transaction' } = {}) {
  const result = await query(
    `SELECT t.*, p.uuid AS property_uuid
     FROM transactions t
     LEFT JOIN properties p ON p.id = t.property_id
     WHERE t.uuid = $1
     LIMIT 1`,
    [transactionUuid],
  );
  const transaction = result.rows[0];
  if (!transaction) {
    throw notFound('Transaction not found.');
  }

  const allowed =
    isAdmin(req) ||
    [transaction.buyer_id, transaction.seller_id, transaction.lawyer_id, transaction.notary_id]
      .filter(Boolean)
      .map(String)
      .includes(String(req.auth.uid));

  if (!allowed) {
    throw forbidden('You do not have access to this transaction.');
  }

  await recordPrivilegedRead({
    req,
    userId: req.auth.uid,
    action,
    entityType: 'transaction',
    entityId: transaction.id,
    details: {
      transaction_uuid: transaction.uuid,
    },
  });

  return transaction;
}

async function requireTransactionActor(req, transaction, allowedActors) {
  if (isAdmin(req)) {
    return 'admin';
  }

  const actorMap = {
    buyer: transaction.buyer_id,
    seller: transaction.seller_id,
    lawyer: transaction.lawyer_id,
    notary: transaction.notary_id,
  };

  const matched = Object.entries(actorMap).find(
    ([actor, userId]) =>
      allowedActors.includes(actor) && userId !== null && userId !== undefined && String(userId) === String(req.auth.uid),
  );

  if (!matched) {
    throw forbidden('Your role on this transaction cannot perform this action.');
  }

  return matched[0];
}

async function requireConversationAccess(req, conversationUuid, { action = 'read_conversation' } = {}) {
  const result = await query(
    `SELECT c.*
     FROM conversations c
     WHERE c.uuid = $1
       AND (
         EXISTS (
           SELECT 1
           FROM conversation_participants cp
           WHERE cp.conversation_id = c.id
             AND cp.user_id = $2
             AND cp.left_at IS NULL
         )
         OR $3::boolean = true
       )
     LIMIT 1`,
    [conversationUuid, req.auth.uid, isAdmin(req)],
  );
  const conversation = result.rows[0];
  if (!conversation) {
    throw notFound('Conversation not found.');
  }

  await recordPrivilegedRead({
    req,
    userId: req.auth.uid,
    action,
    entityType: 'conversation',
    entityId: conversation.id,
    details: { conversation_uuid: conversation.uuid },
  });

  return conversation;
}

async function requireDisputeAccess(req, disputeNumber, { action = 'read_dispute' } = {}) {
  const result = await query(
    `SELECT *
     FROM disputes
     WHERE dispute_number = $1
       AND (
         raised_by_id = $2
         OR raised_against_id = $2
         OR assigned_to_id = $2
         OR $3::boolean = true
       )
     LIMIT 1`,
    [disputeNumber, req.auth.uid, isAdmin(req)],
  );
  const dispute = result.rows[0];
  if (!dispute) {
    throw notFound('Dispute not found.');
  }

  await recordPrivilegedRead({
    req,
    userId: req.auth.uid,
    action,
    entityType: 'dispute',
    entityId: dispute.id,
    details: { dispute_number: dispute.dispute_number },
  });

  return dispute;
}

async function requirePropertyOwnership(req, propertyUuid) {
  const result = await query(
    `SELECT *
     FROM properties
     WHERE uuid = $1
       AND (owner_id = $2 OR listed_by_id = $2)
     LIMIT 1`,
    [propertyUuid, req.auth.uid],
  );
  const property = result.rows[0];
  if (!property) {
    throw notFound('Property not found.');
  }
  return property;
}

async function requireUserSelfOrAdmin(req, userUuid) {
  if (isAdmin(req)) {
    return true;
  }
  const result = await query('SELECT id FROM users WHERE uuid = $1 LIMIT 1', [userUuid]);
  if (!result.rows[0]) {
    throw notFound('User not found.');
  }
  if (String(result.rows[0].id) !== String(req.auth.uid)) {
    throw forbidden('You do not have access to this user record.');
  }
  return true;
}

module.exports = {
  hasRole,
  isAdmin,
  requireConversationAccess,
  requireDisputeAccess,
  requirePropertyOwnership,
  requireTransactionAccess,
  requireTransactionActor,
  requireUserSelfOrAdmin,
};

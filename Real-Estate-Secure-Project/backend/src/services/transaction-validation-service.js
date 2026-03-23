const { query } = require('../db');
const { badRequest, notFound } = require('../lib/errors');

const allowedTransactionTypes = new Set(['sale', 'rent', 'lease']);
const allowedSettlementModes = new Set(['platform_escrow', 'off_platform', 'hybrid']);
const saleCompletionDocumentTypes = new Set([
  'updated_title_evidence',
  'title_transfer_receipt',
]);
const mutationEvidenceDocumentTypes = new Set([
  'registration_receipt',
  'title_mutation_receipt',
]);

async function loadPropertyForTransaction(propertyUuid) {
  const result = await query(
    `SELECT
        p.id,
        p.uuid,
        p.owner_id,
        p.listed_by_id,
        p.listing_type,
        p.property_status,
        p.price,
        p.currency,
        p.risk_lane,
        p.admission_status,
        p.inventory_type,
        p.declared_encumbrance,
        p.declared_dispute,
        p.foreign_party_expected,
        p.old_title_risk,
        p.court_linked,
        p.ministry_filing_required,
        p.municipal_certificate_required,
        p.deleted_at
     FROM properties p
     WHERE p.uuid = $1
     LIMIT 1`,
    [propertyUuid],
  );
  return result.rows[0] ?? null;
}

async function resolveUserByUuid(userUuid, label) {
  if (!userUuid) {
    return null;
  }
  const result = await query(
    `SELECT id, uuid, is_active, is_suspended
     FROM users
     WHERE uuid = $1
     LIMIT 1`,
    [userUuid],
  );
  const row = result.rows[0] ?? null;
  if (!row) {
    throw notFound(`${label} not found.`);
  }
  if (!row.is_active || row.is_suspended) {
    throw badRequest(`${label} is not available for this transaction.`);
  }
  return row;
}

function assertTransactionCreationEligibility({
  property,
  sellerUser,
  buyerUserId,
  transactionType,
  propertyPrice,
  settlementMode,
  assistedLaneReason,
  offlineWorkflowRequired,
}) {
  if (!property) {
    throw notFound('Property not found.');
  }
  if (property.deleted_at) {
    throw badRequest('This property is no longer available.');
  }
  if (property.property_status !== 'active') {
    throw badRequest('Only active properties can enter a transaction.');
  }

  const normalizedTransactionType = String(transactionType || '').trim();
  if (!allowedTransactionTypes.has(normalizedTransactionType)) {
    throw badRequest('Unsupported transaction_type value.');
  }
  if (!allowedSettlementModes.has(String(settlementMode || '').trim())) {
    throw badRequest('Unsupported settlement_mode value.');
  }
  if (normalizedTransactionType !== property.listing_type) {
    throw badRequest('transaction_type must match the property listing_type.');
  }
  if (!Number.isFinite(Number(propertyPrice)) || Number(propertyPrice) <= 0) {
    throw badRequest('property_price must be a positive number.');
  }
  if (Math.abs(Number(property.price) - Number(propertyPrice)) > 1) {
    throw badRequest('property_price must match the active property price.');
  }
  if (String(buyerUserId) === String(sellerUser.id)) {
    throw badRequest('The buyer and seller must be different accounts.');
  }
  if (![property.owner_id, property.listed_by_id].filter(Boolean).map(String).includes(String(sellerUser.id))) {
    throw badRequest('seller_id must match the property owner or listing owner.');
  }

  if (normalizedTransactionType !== 'sale') {
    return;
  }

  if (property.risk_lane === 'blocked' || property.admission_status === 'blocked') {
    throw badRequest('This property is blocked from the sale marketplace lane.');
  }
  if (property.risk_lane === 'government_light' && property.admission_status !== 'eligible') {
    throw badRequest('This sale property is not yet eligible for standard marketplace transactions.');
  }
  if (
    property.risk_lane === 'assisted_only' &&
    offlineWorkflowRequired !== true &&
    !String(assistedLaneReason || '').trim()
  ) {
    throw badRequest('Assisted-only sale files require offline_workflow_required or an assisted_lane_reason.');
  }
}

async function loadTransactionDocumentTypes(transactionId) {
  const result = await query(
    `SELECT document_type
     FROM transaction_documents
     WHERE transaction_id = $1`,
    [transactionId],
  );
  return new Set(result.rows.map((row) => String(row.document_type)));
}

async function hasConfirmedSettlementDeclaration(transactionId) {
  const result = await query(
    `SELECT 1
     FROM transaction_settlement_declarations
     WHERE transaction_id = $1
       AND status = 'confirmed'
     LIMIT 1`,
    [transactionId],
  );
  return result.rowCount > 0;
}

async function assertClosingEvidenceReady(transaction, payload) {
  if (transaction.transaction_type !== 'sale') {
    return;
  }

  const documentTypes = await loadTransactionDocumentTypes(transaction.id);

  if (payload.commercial_close_status === 'commercially_closed') {
    const settledViaEscrow = ['deposited', 'documents_verified', 'inspection_period', 'lawyer_approval', 'completed'].includes(transaction.transaction_status);
    const settledExternally = await hasConfirmedSettlementDeclaration(transaction.id);
    if (!settledViaEscrow && !settledExternally) {
      throw badRequest('Commercial close requires escrow progress or a confirmed external settlement declaration.');
    }
  }

  if (payload.notarial_execution_status === 'notarial_deed_signed') {
    if (!transaction.notary_id) {
      throw badRequest('A notary must be assigned before marking the notarial deed as signed.');
    }
    if (!documentTypes.has('notary_deed')) {
      throw badRequest('Notarial execution requires a notary_deed document in the evidence vault.');
    }
  }

  if (payload.title_confirmation_status === 'mutation_filed') {
    const hasMutationEvidence = Array.from(mutationEvidenceDocumentTypes).some((type) => documentTypes.has(type));
    if (!hasMutationEvidence) {
      throw badRequest('Mutation filing requires a registration_receipt or title_mutation_receipt document.');
    }
  }

  if (payload.title_confirmation_status === 'title_transfer_confirmed') {
    const hasCompletionEvidence = Array.from(saleCompletionDocumentTypes).some((type) => documentTypes.has(type));
    if (!hasCompletionEvidence) {
      throw badRequest('Title transfer confirmation requires updated title evidence or a title transfer receipt.');
    }
  }
}

function assertCompletionReady(transaction) {
  if (transaction.transaction_type !== 'sale') {
    return;
  }
  if (transaction.title_confirmation_status !== 'title_transfer_confirmed') {
    throw badRequest('Sale completion requires title transfer confirmation evidence.');
  }
}

module.exports = {
  assertClosingEvidenceReady,
  assertCompletionReady,
  assertTransactionCreationEligibility,
  hasConfirmedSettlementDeclaration,
  loadPropertyForTransaction,
  loadTransactionDocumentTypes,
  resolveUserByUuid,
};
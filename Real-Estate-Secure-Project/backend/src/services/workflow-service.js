const { badRequest, conflict } = require('../lib/errors');

const transactionTransitions = {
  initiated: {
    buyer: ['pending_deposit', 'deposited', 'cancelled'],
    seller: ['cancelled'],
    lawyer: [],
    notary: [],
    admin: ['pending_deposit', 'deposited', 'cancelled'],
  },
  pending_deposit: {
    buyer: ['deposited', 'cancelled'],
    seller: ['cancelled'],
    lawyer: [],
    notary: [],
    admin: ['deposited', 'cancelled'],
  },
  deposited: {
    buyer: ['inspection_period', 'disputed'],
    seller: [],
    lawyer: ['documents_verified', 'disputed'],
    notary: ['documents_verified', 'disputed'],
    admin: ['inspection_period', 'documents_verified', 'disputed'],
  },
  documents_verified: {
    buyer: ['inspection_period'],
    seller: [],
    lawyer: ['lawyer_approval', 'disputed'],
    notary: ['lawyer_approval', 'disputed'],
    admin: ['inspection_period', 'lawyer_approval', 'disputed'],
  },
  inspection_period: {
    buyer: ['lawyer_approval', 'disputed'],
    seller: [],
    lawyer: ['lawyer_approval', 'disputed'],
    notary: ['lawyer_approval', 'disputed'],
    admin: ['lawyer_approval', 'disputed'],
  },
  lawyer_approval: {
    buyer: [],
    seller: [],
    lawyer: ['completed', 'disputed'],
    notary: ['completed', 'disputed'],
    admin: ['completed', 'disputed', 'cancelled'],
  },
  disputed: {
    buyer: [],
    seller: [],
    lawyer: ['cancelled', 'refunded'],
    notary: ['cancelled', 'refunded'],
    admin: ['cancelled', 'refunded', 'completed'],
  },
  completed: {},
  cancelled: {},
  refunded: {},
};

const closingStateTransitions = {
  commercial_close_status: ['open', 'agreed', 'commercially_closed', 'cancelled'],
  notarial_execution_status: ['pending', 'in_progress', 'notarial_deed_signed', 'filed', 'blocked'],
  title_confirmation_status: ['pending', 'mutation_filed', 'title_transfer_confirmed', 'blocked'],
};

const offlineStepTransitions = {
  awaiting_notary_appointment: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_municipal_certificate: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_registration_receipt: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_mindcaf_filing: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_court_hearing: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_final_judgment: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_non_objection: ['in_review', 'blocked', 'completed', 'cancelled'],
  awaiting_commission_visit: ['in_review', 'blocked', 'completed', 'cancelled'],
  in_review: [
    'awaiting_notary_appointment',
    'awaiting_municipal_certificate',
    'awaiting_registration_receipt',
    'awaiting_mindcaf_filing',
    'awaiting_court_hearing',
    'awaiting_final_judgment',
    'awaiting_non_objection',
    'awaiting_commission_visit',
    'blocked',
    'completed',
    'cancelled',
  ],
  blocked: [
    'awaiting_notary_appointment',
    'awaiting_municipal_certificate',
    'awaiting_registration_receipt',
    'awaiting_mindcaf_filing',
    'awaiting_court_hearing',
    'awaiting_final_judgment',
    'awaiting_non_objection',
    'awaiting_commission_visit',
    'in_review',
    'completed',
    'cancelled',
  ],
  completed: [],
  cancelled: [],
};

const legalCaseTransitions = {
  pending_filing: ['active', 'awaiting_decision', 'blocked', 'closed'],
  active: ['awaiting_decision', 'blocked', 'resolved', 'closed'],
  awaiting_decision: ['blocked', 'resolved', 'closed'],
  blocked: ['pending_filing', 'active', 'awaiting_decision', 'resolved', 'closed'],
  resolved: ['closed'],
  closed: [],
};

const kycTransitions = {
  pending: ['verified', 'rejected'],
  verified: [],
  rejected: ['pending'],
};

const disputeTransitions = {
  open: ['investigating', 'resolved', 'escalated', 'closed'],
  investigating: ['resolved', 'escalated', 'closed'],
  escalated: ['resolved', 'closed'],
  resolved: ['closed'],
  closed: [],
};

function assertOptimisticLock(currentVersion, expectedVersion) {
  if (expectedVersion === undefined || expectedVersion === null || expectedVersion === '') {
    return;
  }
  if (Number(currentVersion) !== Number(expectedVersion)) {
    throw conflict('This record changed before your request was applied. Refresh and try again.');
  }
}

function assertTransition(map, current, next, actor) {
  if (!next || current === next) {
    return;
  }
  const allowed = map[current]?.[actor] ?? map[current] ?? [];
  if (!allowed.includes(next)) {
    throw badRequest(`The transition from ${current} to ${next} is not allowed for ${actor}.`);
  }
}

function assertTransactionTransition(current, next, actor) {
  assertTransition(transactionTransitions, current, next, actor);
}

function assertClosingStateUpdate(currentValue, nextValue, fieldName) {
  if (!nextValue || currentValue === nextValue) {
    return;
  }
  const allowedValues = closingStateTransitions[fieldName] ?? [];
  if (!allowedValues.includes(nextValue)) {
    throw badRequest(`Unsupported ${fieldName} value.`);
  }
}

function assertOfflineStepTransition(current, next) {
  if (!next || current === next) {
    return;
  }
  const allowed = offlineStepTransitions[current] ?? [];
  if (!allowed.includes(next)) {
    throw badRequest(`Offline step status cannot move from ${current} to ${next}.`);
  }
}

function assertLegalCaseTransition(current, next) {
  if (!next || current === next) {
    return;
  }
  const allowed = legalCaseTransitions[current] ?? [];
  if (!allowed.includes(next)) {
    throw badRequest(`Legal case status cannot move from ${current} to ${next}.`);
  }
}

function assertKycTransition(current, next) {
  if (!next || current === next) {
    return;
  }
  const allowed = kycTransitions[current] ?? [];
  if (!allowed.includes(next)) {
    throw badRequest(`KYC status cannot move from ${current} to ${next}.`);
  }
}

function assertDisputeTransition(current, next) {
  if (!next || current === next) {
    return;
  }
  const allowed = disputeTransitions[current] ?? [];
  if (!allowed.includes(next)) {
    throw badRequest(`Dispute status cannot move from ${current} to ${next}.`);
  }
}

module.exports = {
  assertClosingStateUpdate,
  assertDisputeTransition,
  assertKycTransition,
  assertLegalCaseTransition,
  assertOfflineStepTransition,
  assertOptimisticLock,
  assertTransactionTransition,
};

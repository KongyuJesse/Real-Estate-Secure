const { closePools, query } = require('../db');
const { config } = require('../config');
const {
  createInAppNotification,
  loadUserNotificationProfile,
  queueTemplatedNotification,
} = require('../services/notification-service');
const { connectRedis } = require('../services/redis-service');
const { listPendingOutboxEvents, markOutboxFailed, markOutboxPublished } = require('../services/outbox-service');
const { publish } = require('../services/realtime-service');

let timer;
let shuttingDown = false;

function logInfo(message) {
  console.log(`${new Date().toISOString()} INFO ${message}`);
}

function logError(message) {
  console.error(`${new Date().toISOString()} ERROR ${message}`);
}

function humanize(value) {
  return String(value || '')
    .split(/[_\-\s]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

async function notifyUser(userId, {
  notificationType,
  title,
  body,
  severity = 'info',
  category = 'activity',
  actionUrl = null,
  actionLabel = null,
  dedupeKey,
  metadata = {},
  emailTemplate = null,
  smsTemplate = null,
  templateVariables = {},
}) {
  const profile = await loadUserNotificationProfile(userId);
  if (!profile) {
    return;
  }

  await createInAppNotification({
    userId,
    notificationType,
    title,
    body,
    severity,
    category,
    actionUrl,
    actionLabel,
    metadata,
    dedupeKey,
  });

  if (emailTemplate && profile.email && profile.email_notifications_enabled) {
    await queueTemplatedNotification({
      userId,
      channel: 'email',
      recipient: profile.email,
      templateName: emailTemplate,
      locale: profile.locale ?? config.defaultLanguage,
      variables: templateVariables,
      metadata: {
        ...metadata,
        event_dedupe_key: dedupeKey,
      },
    });
  }

  if (smsTemplate && profile.phone_number && profile.sms_notifications_enabled) {
    await queueTemplatedNotification({
      userId,
      channel: 'sms',
      recipient: profile.phone_number,
      templateName: smsTemplate,
      locale: profile.locale ?? config.defaultLanguage,
      variables: templateVariables,
      metadata: {
        ...metadata,
        event_dedupe_key: dedupeKey,
      },
    });
  }
}

async function handleUserRegistered(event) {
  const userResult = await query(
    `SELECT id
     FROM users
     WHERE uuid = $1
     LIMIT 1`,
    [event.aggregate_id],
  );
  const userId = userResult.rows[0]?.id;
  if (!userId) {
    return;
  }
  const profile = await loadUserNotificationProfile(userId);
  if (!profile?.email || !profile.email_notifications_enabled) {
    return;
  }
  await queueTemplatedNotification({
    userId,
    channel: 'email',
    recipient: profile.email,
    templateName: 'welcome',
    locale: profile.locale ?? config.defaultLanguage,
    variables: {
      first_name: profile.first_name || 'there',
    },
    metadata: {
      event_id: event.id,
    },
  });
}

async function handleKycSubmitted(event) {
  const documentId = event.payload?.document_id;
  if (!documentId) {
    return;
  }
  const result = await query(
    `SELECT
        d.id,
        d.user_id,
        d.document_type,
        d.document_number,
        d.verification_status,
        u.uuid AS user_uuid,
        u.first_name
     FROM identity_documents d
     JOIN users u ON u.id = d.user_id
     WHERE d.id = $1
     LIMIT 1`,
    [documentId],
  );
  const row = result.rows[0];
  if (!row) {
    return;
  }

  await notifyUser(row.user_id, {
    notificationType: 'kyc_submission_received',
    title: 'KYC documents received',
    body: `Your ${humanize(row.document_type)} file ${row.document_number} is now under review.`,
    category: 'verification',
    actionUrl: '/profile/verification',
    actionLabel: 'Track review',
    dedupeKey: `outbox:${event.id}:kyc:${row.id}:user:${row.user_id}`,
    metadata: {
      document_id: row.id,
      user_uuid: row.user_uuid,
    },
    emailTemplate: 'kyc_submission_received',
    smsTemplate: 'kyc_submission_received',
    templateVariables: {
      first_name: row.first_name || 'there',
      document_type: humanize(row.document_type),
      document_number: row.document_number,
      status_label: humanize(row.verification_status || 'pending'),
    },
  });
}

async function handleConversationMessageCreated(event) {
  const messageId = event.payload?.message_id;
  const conversationUuid = event.payload?.conversation_id;
  if (!messageId || !conversationUuid) {
    return;
  }

  const detailsResult = await query(
    `SELECT
        c.id AS conversation_id,
        c.uuid AS conversation_uuid,
        COALESCE(NULLIF(c.title, ''), 'Secure conversation') AS conversation_title,
        LEFT(m.content, 180) AS message_preview,
        sender.id AS sender_user_id,
        sender.uuid AS sender_uuid,
        CONCAT_WS(' ', sender.first_name, sender.last_name) AS sender_name
     FROM conversations c
     JOIN messages m ON m.conversation_id = c.id
     JOIN users sender ON sender.id = m.sender_id
     WHERE c.uuid = $1
       AND m.id = $2
     LIMIT 1`,
    [conversationUuid, messageId],
  );
  const details = detailsResult.rows[0];
  if (!details) {
    return;
  }

  const recipientsResult = await query(
    `SELECT user_id
     FROM conversation_participants
     WHERE conversation_id = $1
       AND left_at IS NULL
       AND user_id <> $2`,
    [details.conversation_id, details.sender_user_id],
  );

  await Promise.all(
    recipientsResult.rows.map((row) => notifyUser(row.user_id, {
      notificationType: 'message_received',
      title: `New message from ${details.sender_name || 'a participant'}`,
      body: details.message_preview || 'Open the conversation to review the latest message.',
      category: 'messaging',
      actionUrl: `/messages/${details.conversation_uuid}`,
      actionLabel: 'Open inbox',
      dedupeKey: `outbox:${event.id}:conversation:${details.conversation_uuid}:recipient:${row.user_id}`,
      metadata: {
        conversation_uuid: details.conversation_uuid,
        message_id: messageId,
        sender_uuid: details.sender_uuid,
      },
      emailTemplate: 'message_received',
      smsTemplate: 'message_received',
      templateVariables: {
        sender_name: details.sender_name || 'a participant',
        conversation_title: details.conversation_title,
        message_preview: details.message_preview || '',
      },
    })),
  );
}

async function loadTransactionAudience(transactionUuid) {
  const result = await query(
    `SELECT
        t.id,
        t.uuid,
        t.transaction_number,
        t.transaction_status,
        t.commercial_close_status,
        t.notarial_execution_status,
        t.title_confirmation_status,
        t.buyer_id,
        t.seller_id,
        t.lawyer_id,
        t.notary_id,
        p.title AS property_title
     FROM transactions t
     LEFT JOIN properties p ON p.id = t.property_id
     WHERE t.uuid = $1
     LIMIT 1`,
    [transactionUuid],
  );
  return result.rows[0] ?? null;
}

async function notifyTransactionParticipants(event, stageLabel, summaryLine) {
  const transactionUuid = event.payload?.transaction_uuid || event.aggregate_id;
  const transaction = await loadTransactionAudience(transactionUuid);
  if (!transaction) {
    return;
  }

  const recipientIds = [
    transaction.buyer_id,
    transaction.seller_id,
    transaction.lawyer_id,
    transaction.notary_id,
  ].filter(Boolean);
  const uniqueRecipients = [...new Set(recipientIds.map((value) => Number(value)))];

  await Promise.all(
    uniqueRecipients.map((userId) => notifyUser(userId, {
      notificationType: 'transaction_stage_update',
      title: `Transaction update: ${stageLabel}`,
      body: `${transaction.transaction_number} for ${transaction.property_title || 'your file'} is now at ${stageLabel.toLowerCase()}.`,
      category: 'transactions',
      actionUrl: `/transactions/${transaction.uuid}`,
      actionLabel: 'Open file',
      dedupeKey: `outbox:${event.id}:transaction:${transaction.uuid}:recipient:${userId}`,
      metadata: {
        transaction_uuid: transaction.uuid,
      },
      emailTemplate: 'transaction_stage_update',
      templateVariables: {
        stage_label: stageLabel,
        transaction_number: transaction.transaction_number,
        property_title: transaction.property_title || 'Property file',
        summary_line: summaryLine,
      },
    })),
  );
}

async function handleTransactionCreated(event) {
  await notifyTransactionParticipants(
    event,
    'Transaction opened',
    'The commercial file is open and ready for the next required action.',
  );
}

async function handleTransactionStatusChanged(event) {
  const stageLabel = humanize(event.payload?.status || 'updated');
  await notifyTransactionParticipants(
    event,
    stageLabel,
    `Current transaction status: ${stageLabel}. Review the file for the next required task.`,
  );
}

async function handleTransactionClosingStageUpdated(event) {
  const commercial = humanize(event.payload?.commercial_close_status || 'open');
  const notarial = humanize(event.payload?.notarial_execution_status || 'pending');
  const titleConfirmation = humanize(event.payload?.title_confirmation_status || 'pending');
  await notifyTransactionParticipants(
    event,
    'Closing file updated',
    `Commercial close: ${commercial}. Notarial execution: ${notarial}. Title confirmation: ${titleConfirmation}.`,
  );
}

async function handleTransactionAssignment(event, assignmentType) {
  const assignedUuid = event.payload?.[`${assignmentType}_uuid`];
  if (!assignedUuid) {
    return;
  }
  const userResult = await query(
    `SELECT id
     FROM users
     WHERE uuid = $1
     LIMIT 1`,
    [assignedUuid],
  );
  const userId = userResult.rows[0]?.id;
  if (!userId) {
    return;
  }
  const transaction = await loadTransactionAudience(event.payload?.transaction_uuid || event.aggregate_id);
  if (!transaction) {
    return;
  }

  await notifyUser(userId, {
    notificationType: `${assignmentType}_assignment_received`,
    title: `${humanize(assignmentType)} assignment received`,
    body: `You were assigned to transaction ${transaction.transaction_number} for ${transaction.property_title || 'a property file'}.`,
    category: 'transactions',
    actionUrl: `/transactions/${transaction.uuid}`,
    actionLabel: 'Review file',
    dedupeKey: `outbox:${event.id}:assignment:${assignmentType}:recipient:${userId}`,
    metadata: {
      transaction_uuid: transaction.uuid,
    },
  });
}

async function handleDisputeCreated(event) {
  const disputeNumber = event.aggregate_id;
  const result = await query(
    `SELECT id, dispute_number, raised_by_id, raised_against_id, assigned_to_id
     FROM disputes
     WHERE dispute_number = $1
     LIMIT 1`,
    [disputeNumber],
  );
  const dispute = result.rows[0];
  if (!dispute) {
    return;
  }

  const recipients = [
    dispute.raised_by_id,
    dispute.raised_against_id,
    dispute.assigned_to_id,
  ].filter(Boolean);
  const uniqueRecipients = [...new Set(recipients.map((value) => Number(value)))];

  await Promise.all(
    uniqueRecipients.map((userId) => notifyUser(userId, {
      notificationType: 'dispute_created',
      title: `Dispute opened: ${dispute.dispute_number}`,
      body: 'A dispute file was opened and is now available for review.',
      severity: 'warning',
      category: 'governance',
      actionUrl: `/disputes/${dispute.dispute_number}`,
      actionLabel: 'Review dispute',
      dedupeKey: `outbox:${event.id}:dispute:${dispute.dispute_number}:recipient:${userId}`,
      metadata: {
        dispute_number: dispute.dispute_number,
      },
    })),
  );
}

async function handleEvent(event) {
  switch (event.topic) {
    case 'user.registered':
      await handleUserRegistered(event);
      return;
    case 'kyc.submitted':
      await handleKycSubmitted(event);
      return;
    case 'conversation.message_created':
      await handleConversationMessageCreated(event);
      return;
    case 'transaction.created':
      await handleTransactionCreated(event);
      return;
    case 'transaction.status_changed':
      await handleTransactionStatusChanged(event);
      return;
    case 'transaction.closing_stage_updated':
      await handleTransactionClosingStageUpdated(event);
      return;
    case 'transaction.lawyer_assigned':
      await handleTransactionAssignment(event, 'lawyer');
      return;
    case 'transaction.notary_assigned':
      await handleTransactionAssignment(event, 'notary');
      return;
    case 'dispute.created':
      await handleDisputeCreated(event);
      return;
    default:
      return;
  }
}

async function processOutboxBatch() {
  const events = await listPendingOutboxEvents(50);
  for (const event of events) {
    try {
      await handleEvent(event);
      await publish(`outbox:${event.topic}`, {
        id: event.id,
        topic: event.topic,
        aggregate_type: event.aggregate_type,
        aggregate_id: event.aggregate_id,
        payload: event.payload,
        created_at: event.created_at,
      });
      await markOutboxPublished(event.id);
    } catch (error) {
      await markOutboxFailed(event.id, error.message);
      logError(`Outbox event ${event.id} failed: ${error.message}`);
    }
  }
}

async function tick() {
  if (shuttingDown) {
    return;
  }
  try {
    await processOutboxBatch();
  } catch (error) {
    logError(`Worker tick failed: ${error.message}`);
  }
}

async function shutdown(signal) {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  if (timer) {
    clearInterval(timer);
  }
  logInfo(`Worker received ${signal}; shutting down.`);
  await closePools().catch(() => {});
  process.exit(0);
}

async function start() {
  await connectRedis().catch(() => null);
  logInfo(`Worker started with poll interval ${config.jobPollIntervalMs}ms.`);
  await tick();
  timer = setInterval(() => {
    void tick();
  }, Math.max(3000, config.jobPollIntervalMs));
}

process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});

start().catch(async (error) => {
  logError(`Worker startup failed: ${error.message}`);
  await closePools().catch(() => {});
  process.exit(1);
});

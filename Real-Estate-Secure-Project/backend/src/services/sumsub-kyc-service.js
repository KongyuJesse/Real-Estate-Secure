const crypto = require('crypto');

const { query } = require('../db');
const { config } = require('../config');
const { AppError, badRequest, notFound } = require('../lib/errors');
const { canonicalizeRole } = require('../lib/mobile-roles');

const PROVIDER_NAME = 'sumsub';
const CONTACT_ACTION_PREFIX = 'res:contact';
const CONTACT_VERIFICATION_CHANNELS = new Set(['email', 'phone']);

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function ensureSumsubConfigured() {
  if (!config.sumsubAppToken || !config.sumsubSecretKey) {
    throw new AppError(
      'Sumsub is not configured yet. Add the Sumsub app token and secret key on the backend first.',
      503,
      'SUMSUB_NOT_CONFIGURED',
    );
  }
}

function buildExternalUserId(userUuid) {
  return `res:${String(userUuid || '').trim()}`;
}

function normalizeKycRole(role) {
  const normalized = canonicalizeRole(role);
  switch (normalized) {
    case 'seller':
    case 'lawyer':
    case 'notary':
      return normalized;
    default:
      return 'buyer';
  }
}

function roleLabel(role) {
  switch (normalizeKycRole(role)) {
    case 'seller':
      return 'Seller';
    case 'lawyer':
      return 'Lawyer';
    case 'notary':
      return 'Notary';
    default:
      return 'Buyer';
  }
}

function resolveKycLevelName(role) {
  switch (normalizeKycRole(role)) {
    case 'seller':
      return config.sumsubLevelNameSeller || config.sumsubLevelName;
    case 'lawyer':
      return config.sumsubLevelNameLawyer || config.sumsubLevelName;
    case 'notary':
      return config.sumsubLevelNameNotary || config.sumsubLevelName;
    default:
      return config.sumsubLevelNameBuyer || config.sumsubLevelName;
  }
}

function normalizeContactVerificationChannel(channel) {
  const normalized = String(channel || '').trim().toLowerCase();
  if (!CONTACT_VERIFICATION_CHANNELS.has(normalized)) {
    throw badRequest('Contact verification channel must be email or phone.');
  }
  return normalized;
}

function buildContactVerificationActionId({ userUuid, channel }) {
  const normalizedChannel = normalizeContactVerificationChannel(channel);
  const normalizedUserUuid = String(userUuid || '').trim();
  if (!normalizedUserUuid) {
    throw badRequest('userUuid is required for Sumsub contact verification.');
  }
  return `${CONTACT_ACTION_PREFIX}:${normalizedChannel}:${normalizedUserUuid}:${Date.now()}`;
}

function parseContactVerificationActionId(externalActionId) {
  const raw = String(externalActionId || '').trim();
  if (!raw.startsWith(`${CONTACT_ACTION_PREFIX}:`)) {
    return null;
  }

  const parts = raw.split(':');
  if (parts.length < 5) {
    return null;
  }

  const channel = parts[2]?.trim().toLowerCase();
  const userUuid = parts[3]?.trim();
  if (!CONTACT_VERIFICATION_CHANNELS.has(channel) || !userUuid) {
    return null;
  }

  return {
    channel,
    userUuid,
  };
}

function resolveContactVerificationLevelName(channel) {
  normalizeContactVerificationChannel(channel);
  return config.sumsubContactActionLevelName;
}

function sumsubTimestamp() {
  return Math.floor(Date.now() / 1000).toString();
}

function signSumsubRequest({ method, path, body = '' }) {
  const timestamp = sumsubTimestamp();
  const payload = `${timestamp}${method.toUpperCase()}${path}${body}`;
  const signature = crypto
    .createHmac('sha256', config.sumsubSecretKey)
    .update(payload)
    .digest('hex');

  return {
    'X-App-Token': config.sumsubAppToken,
    'X-App-Access-Ts': timestamp,
    'X-App-Access-Sig': signature,
  };
}

async function parseJsonResponse(response) {
  const raw = await response.text();
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw);
  } catch (_) {
    return raw;
  }
}

async function requestSumsub({
  method,
  path,
  body,
}) {
  ensureSumsubConfigured();

  const jsonBody = body === undefined ? '' : JSON.stringify(body);
  const headers = {
    Accept: 'application/json',
    ...signSumsubRequest({ method, path, body: jsonBody }),
  };

  if (jsonBody) {
    headers['Content-Type'] = 'application/json';
  }

  const response = await fetch(`${config.sumsubApiBaseUrl}${path}`, {
    method,
    headers,
    body: jsonBody || undefined,
  });

  const payload = await parseJsonResponse(response);
  if (!response.ok) {
    const description = isObject(payload) ? payload.description : null;
    throw new AppError(
      description || 'Sumsub request failed.',
      response.status >= 500 ? 502 : response.status,
      'SUMSUB_REQUEST_FAILED',
      payload,
    );
  }

  return payload;
}

function mapReviewToVerificationStatus(reviewStatus, reviewResult = {}) {
  const normalizedStatus = String(reviewStatus || '').trim().toLowerCase();
  const reviewAnswer = String(reviewResult.reviewAnswer || '').trim().toUpperCase();

  if (normalizedStatus === 'completed' && reviewAnswer === 'GREEN') {
    return 'verified';
  }

  if (normalizedStatus === 'completed' && reviewAnswer === 'RED') {
    return 'rejected';
  }

  return 'pending';
}

function parseWebhookTimestamp(payload) {
  const rawValue = payload?.createdAtMs ?? payload?.createdAt;
  if (!rawValue) {
    return new Date();
  }

  const parsed = new Date(rawValue);
  if (!Number.isNaN(parsed.getTime())) {
    return parsed;
  }

  return new Date();
}

function extractApplicantMetadata(applicantData) {
  if (!isObject(applicantData)) {
    return null;
  }

  const info = isObject(applicantData.info) ? applicantData.info : {};
  const fixedInfo = isObject(applicantData.fixedInfo) ? applicantData.fixedInfo : {};
  const review = isObject(applicantData.review) ? applicantData.review : {};
  const reviewResult = isObject(review.reviewResult) ? review.reviewResult : {};
  const firstIdDoc = Array.isArray(info.idDocs) && isObject(info.idDocs[0]) ? info.idDocs[0] : {};

  return {
    applicant_id: applicantData.id ?? null,
    inspection_id: applicantData.inspectionId ?? null,
    level_name: applicantData.levelName ?? null,
    applicant_type: applicantData.type ?? applicantData.applicantType ?? null,
    review: {
      review_status: review.reviewStatus ?? null,
      review_answer: reviewResult.reviewAnswer ?? null,
      review_reject_type: reviewResult.reviewRejectType ?? null,
    },
    identity: {
      first_name: info.firstName ?? fixedInfo.firstName ?? null,
      last_name: info.lastName ?? fixedInfo.lastName ?? null,
      dob: info.dob ?? fixedInfo.dob ?? null,
      document_type: firstIdDoc.idDocType ?? null,
      document_country: firstIdDoc.country ?? null,
      document_number: firstIdDoc.number ?? null,
    },
  };
}

function extractApplicantReviewSnapshot(applicantData) {
  const review = isObject(applicantData?.review) ? applicantData.review : {};
  const reviewResult = isObject(review.reviewResult) ? review.reviewResult : {};
  const reviewStatus = String(review.reviewStatus || '').trim() || 'init';
  const reviewAnswer =
    String(reviewResult.reviewAnswer || '').trim().toUpperCase() || null;
  const reviewRejectType =
    String(reviewResult.reviewRejectType || '').trim().toUpperCase() || null;

  return {
    reviewStatus,
    reviewAnswer,
    reviewRejectType,
    reviewResult,
    verificationStatus: mapReviewToVerificationStatus(reviewStatus, reviewResult),
  };
}

async function getApplicantDataByExternalUserId(externalUserId) {
  if (!externalUserId) {
    return null;
  }

  const encoded = encodeURIComponent(externalUserId);
  return requestSumsub({
    method: 'GET',
    path: `/resources/applicants/-;externalUserId=${encoded}/one`,
  });
}

async function listApplicantActions(applicantId) {
  if (!applicantId) {
    return [];
  }

  const encoded = encodeURIComponent(applicantId);
  const payload = await requestSumsub({
    method: 'GET',
    path: `/resources/applicantActions/-;applicantId=${encoded}`,
  });

  if (Array.isArray(payload)) {
    return payload;
  }
  if (Array.isArray(payload?.items)) {
    return payload.items;
  }
  return [];
}

function extractApplicantActionReviewSnapshot(actionData) {
  const review = isObject(actionData?.review) ? actionData.review : {};
  const reviewResult = isObject(review.reviewResult)
    ? review.reviewResult
    : isObject(actionData?.reviewResult)
      ? actionData.reviewResult
      : {};
  const reviewStatus = String(
    actionData?.reviewStatus || review.reviewStatus || '',
  ).trim() || 'init';
  const reviewAnswer =
    String(reviewResult.reviewAnswer || '').trim().toUpperCase() || null;
  const reviewRejectType =
    String(reviewResult.reviewRejectType || '').trim().toUpperCase() || null;

  return {
    actionId:
      actionData?.id?.toString()
      || actionData?.applicantActionId?.toString()
      || null,
    externalActionId: actionData?.externalActionId?.toString() || null,
    applicantId:
      actionData?.applicantId?.toString()
      || actionData?.applicant?.toString()
      || null,
    reviewStatus,
    reviewAnswer,
    reviewRejectType,
    verificationStatus: mapReviewToVerificationStatus(reviewStatus, reviewResult),
    reviewResult,
  };
}

function applicantActionSortValue(action) {
  const rawValue =
    action?.createdAt
    || action?.createdAtMs
    || action?.review?.createdAt
    || action?.reviewResult?.createdAt;
  if (!rawValue) {
    return 0;
  }
  const parsed = new Date(rawValue).getTime();
  return Number.isNaN(parsed) ? 0 : parsed;
}

async function syncContactVerificationState({
  userId,
  channel,
  verificationStatus,
}) {
  const normalizedChannel = normalizeContactVerificationChannel(channel);
  if (verificationStatus !== 'verified') {
    return false;
  }

  const column = normalizedChannel === 'email'
    ? 'email_verified_at'
    : 'phone_verified_at';
  const result = await query(
    `UPDATE users
     SET ${column} = COALESCE(${column}, now()),
         updated_at = now()
     WHERE id = $1
     RETURNING ${column} IS NOT NULL AS verified`,
    [userId],
  );

  return result.rows[0]?.verified === true;
}

async function createSumsubContactVerificationSession({
  userId,
  userUuid,
  channel,
}) {
  const normalizedChannel = normalizeContactVerificationChannel(channel);
  const externalUserId = buildExternalUserId(userUuid);
  const externalActionId = buildContactVerificationActionId({
    userUuid,
    channel: normalizedChannel,
  });
  const levelName = resolveContactVerificationLevelName(normalizedChannel);

  const tokenResponse = await requestSumsub({
    method: 'POST',
    path: '/resources/accessTokens/sdk',
    body: {
      userId: externalUserId,
      levelName,
      externalActionId,
      ttlInSecs: config.sumsubAccessTokenTtlSec,
    },
  });

  const expiresAt = new Date(Date.now() + config.sumsubAccessTokenTtlSec * 1000);
  return {
    provider: PROVIDER_NAME,
    display_name: normalizedChannel === 'email'
      ? 'Sumsub email verification'
      : 'Sumsub phone verification',
    access_token: tokenResponse?.token?.toString() ?? '',
    external_user_id: externalUserId,
    external_action_id: externalActionId,
    level_name: levelName,
    purpose: `${normalizedChannel}_verification`,
    verification_status: 'pending',
    review_status: 'init',
    review_answer: null,
    review_reject_type: null,
    expires_at: expiresAt.toISOString(),
    capture_fallback_policy: 'no_fallback',
  };
}

async function refreshSumsubContactVerification({
  userId,
  userUuid,
  channel,
  externalActionId,
}) {
  const normalizedChannel = normalizeContactVerificationChannel(channel);
  const externalUserId = buildExternalUserId(userUuid);
  const applicantData = await getApplicantDataByExternalUserId(externalUserId);
  const applicantId = applicantData?.id?.toString() ?? '';
  if (!applicantId) {
    return {
      channel: normalizedChannel,
      verified: false,
      external_action_id: externalActionId?.trim() || null,
      review_status: 'init',
      review_answer: null,
      review_reject_type: null,
      verification_status: 'pending',
    };
  }

  const requestedActionId = String(externalActionId || '').trim();
  const actions = await listApplicantActions(applicantId);
  const matchingActions = actions
    .filter((item) => {
      const snapshot = extractApplicantActionReviewSnapshot(item);
      if (requestedActionId) {
        return snapshot.externalActionId === requestedActionId;
      }
      const parsedActionId = parseContactVerificationActionId(
        snapshot.externalActionId,
      );
      return (
        parsedActionId?.channel === normalizedChannel
        && parsedActionId.userUuid === String(userUuid || '').trim()
      );
    })
    .sort((left, right) => applicantActionSortValue(right) - applicantActionSortValue(left));

  const latest = matchingActions[0] ?? null;
  if (!latest) {
    return {
      channel: normalizedChannel,
      verified: false,
      external_action_id: requestedActionId || null,
      review_status: 'init',
      review_answer: null,
      review_reject_type: null,
      verification_status: 'pending',
    };
  }

  const snapshot = extractApplicantActionReviewSnapshot(latest);
  const verified = await syncContactVerificationState({
    userId,
    channel: normalizedChannel,
    verificationStatus: snapshot.verificationStatus,
  });

  return {
    channel: normalizedChannel,
    verified,
    external_action_id: snapshot.externalActionId,
    review_status: snapshot.reviewStatus,
    review_answer: snapshot.reviewAnswer,
    review_reject_type: snapshot.reviewRejectType,
    verification_status: snapshot.verificationStatus,
  };
}

async function updateProviderCaseFromApplicantData({
  providerCaseId,
  applicantData,
  eventType = 'admin_refresh_snapshot',
  correlationId,
}) {
  if (!providerCaseId) {
    throw badRequest('providerCaseId is required.');
  }

  const snapshot = extractApplicantReviewSnapshot(applicantData);
  const metadata = extractApplicantMetadata(applicantData);
  const eventTimestamp = new Date();

  await query(
    `UPDATE kyc_provider_cases
     SET provider_applicant_id = COALESCE(NULLIF($2, ''), provider_applicant_id),
         inspection_id = COALESCE(NULLIF($3, ''), inspection_id),
         level_name = COALESCE(NULLIF($4, ''), level_name),
         verification_status = $5,
         provider_review_status = $6,
         provider_review_answer = $7,
         provider_review_reject_type = $8,
         latest_event_type = $9,
         moderation_comment = NULLIF($10, ''),
         client_comment = NULLIF($11, ''),
         rejection_labels = CASE
           WHEN $12::jsonb IS NULL THEN rejection_labels
           ELSE $12::jsonb
         END,
         raw_provider_payload = $13::jsonb,
         provider_metadata = CASE
           WHEN $14::jsonb IS NULL THEN provider_metadata
           ELSE COALESCE(provider_metadata, '{}'::jsonb) || $14::jsonb
         END,
         last_event_at = $15,
         verified_at = CASE
           WHEN $5 = 'verified' THEN COALESCE(verified_at, $15)
           WHEN $5 = 'rejected' THEN NULL
           ELSE verified_at
         END,
         updated_at = now(),
         row_version = row_version + 1
     WHERE id = $1`,
    [
      providerCaseId,
      applicantData?.id ?? '',
      applicantData?.inspectionId ?? '',
      applicantData?.levelName ?? '',
      snapshot.verificationStatus,
      snapshot.reviewStatus,
      snapshot.reviewAnswer,
      snapshot.reviewRejectType,
      eventType,
      String(snapshot.reviewResult?.moderationComment || '').trim(),
      String(snapshot.reviewResult?.clientComment || '').trim(),
      Array.isArray(snapshot.reviewResult?.rejectLabels)
        ? JSON.stringify(snapshot.reviewResult.rejectLabels)
        : null,
      JSON.stringify(applicantData ?? {}),
      metadata ? JSON.stringify(metadata) : null,
      eventTimestamp.toISOString(),
    ],
  );

  if (correlationId) {
    await query(
      `INSERT INTO kyc_provider_events (
           provider_case_id,
           provider,
           correlation_id,
           event_type,
           applicant_id,
           inspection_id,
           external_user_id,
           review_status,
           review_answer,
           review_reject_type,
           payload
         )
         VALUES (
           $1,
           $2,
           $3,
           $4,
           NULLIF($5, ''),
           NULLIF($6, ''),
           NULLIF($7, ''),
           NULLIF($8, ''),
           NULLIF($9, ''),
           NULLIF($10, ''),
           $11::jsonb
         )
         ON CONFLICT (provider, correlation_id) DO NOTHING`,
      [
        providerCaseId,
        PROVIDER_NAME,
        correlationId,
        eventType,
        applicantData?.id ?? '',
        applicantData?.inspectionId ?? '',
        applicantData?.externalUserId ?? '',
        snapshot.reviewStatus,
        snapshot.reviewAnswer,
        snapshot.reviewRejectType,
        JSON.stringify(applicantData ?? {}),
      ],
    );
  }

  const refreshed = await query(
    `SELECT
        id,
        provider,
        external_user_id,
        provider_applicant_id,
        inspection_id,
        level_name,
        verification_status::text AS verification_status,
        provider_review_status,
        provider_review_answer,
        provider_review_reject_type,
        latest_event_type,
        moderation_comment,
        client_comment,
        rejection_labels,
        provider_metadata,
        started_at,
        last_event_at,
        verified_at,
        row_version,
        created_at,
        updated_at
     FROM kyc_provider_cases
     WHERE id = $1
     LIMIT 1`,
    [providerCaseId],
  );

  return refreshed.rows[0] ?? null;
}

function verifyWebhookDigest(rawBody, headers) {
  if (!config.sumsubWebhookSecret) {
    return;
  }

  const digestHeader = headers['x-payload-digest'];
  const digestAlgHeader = headers['x-payload-digest-alg'];
  if (!digestHeader || !digestAlgHeader) {
    throw new AppError(
      'Sumsub webhook signature headers are missing.',
      401,
      'SUMSUB_WEBHOOK_SIGNATURE_MISSING',
    );
  }

  const algorithm = {
    HMAC_SHA1_HEX: 'sha1',
    HMAC_SHA256_HEX: 'sha256',
    HMAC_SHA512_HEX: 'sha512',
  }[String(digestAlgHeader).trim().toUpperCase()];

  if (!algorithm) {
    throw new AppError(
      'Unsupported Sumsub webhook digest algorithm.',
      401,
      'SUMSUB_WEBHOOK_SIGNATURE_UNSUPPORTED',
    );
  }

  const calculated = crypto
    .createHmac(algorithm, config.sumsubWebhookSecret)
    .update(rawBody || '', 'utf8')
    .digest('hex');

  const provided = String(digestHeader).trim().toLowerCase();
  if (calculated.length !== provided.length) {
    throw new AppError(
      'Sumsub webhook signature mismatch.',
      401,
      'SUMSUB_WEBHOOK_SIGNATURE_INVALID',
    );
  }
  const matches = crypto.timingSafeEqual(
    Buffer.from(calculated, 'utf8'),
    Buffer.from(provided, 'utf8'),
  );

  if (!matches) {
    throw new AppError(
      'Sumsub webhook signature mismatch.',
      401,
      'SUMSUB_WEBHOOK_SIGNATURE_INVALID',
    );
  }
}

async function getUserKycOverview(userId) {
  const result = await query(
    `WITH provider_records AS (
        SELECT verification_status::text AS verification_status, created_at
        FROM kyc_provider_cases
        WHERE user_id = $1
          AND provider = $2
      )
      SELECT
        EXISTS(SELECT 1 FROM provider_records) AS has_any_record,
        EXISTS(SELECT 1 FROM provider_records WHERE verification_status = 'verified') AS has_verified_record,
        (
          SELECT verification_status
          FROM provider_records
          ORDER BY created_at DESC
          LIMIT 1
        ) AS latest_status`,
    [userId, PROVIDER_NAME],
  );

  const row = result.rows[0] ?? {};
  return {
    hasAnyRecord: row.has_any_record === true,
    hasVerifiedRecord: row.has_verified_record === true,
    latestStatus: row.latest_status?.toString() ?? '',
  };
}

async function listUserKycRecords(userId) {
  const result = await query(
    `SELECT
        CONCAT('provider:', k.id) AS id,
        k.provider,
        'provider_sdk' AS flow_kind,
        CASE
          WHEN k.provider = 'sumsub' THEN 'Sumsub live verification'
          ELSE 'Provider verification'
        END AS title,
        k.level_name AS reference,
        NULL::text AS document_type,
        NULL::text AS document_number,
        k.verification_status::text AS verification_status,
        k.provider_review_status AS review_status,
        k.provider_review_answer AS review_answer,
        k.provider_review_reject_type AS review_reject_type,
        COALESCE(k.moderation_comment, k.client_comment, '') AS latest_note,
        k.created_at,
        k.verified_at
     FROM kyc_provider_cases k
     WHERE k.user_id = $1
       AND k.provider = $2
     ORDER BY k.created_at DESC`,
    [userId, PROVIDER_NAME],
  );

  return result.rows;
}

async function createOrRefreshSumsubSession({
  userId,
  userUuid,
  email,
  phone,
  role,
}) {
  const normalizedRole = normalizeKycRole(role);
  const levelName = resolveKycLevelName(normalizedRole);
  const externalUserId = buildExternalUserId(userUuid);
  const applicantIdentifiers = {};
  const normalizedEmail = String(email || '').trim();
  const normalizedPhone = String(phone || '').trim();
  if (normalizedEmail.length > 0) {
    applicantIdentifiers.email = normalizedEmail;
  }
  if (normalizedPhone.length > 0) {
    applicantIdentifiers.phone = normalizedPhone;
  }

  const tokenResponse = await requestSumsub({
    method: 'POST',
    path: '/resources/accessTokens/sdk',
    body: {
      userId: externalUserId,
      levelName,
      ttlInSecs: config.sumsubAccessTokenTtlSec,
      ...(Object.keys(applicantIdentifiers).length > 0
        ? { applicantIdentifiers }
        : {}),
    },
  });

  const expiresAt = new Date(Date.now() + config.sumsubAccessTokenTtlSec * 1000);
  const metadataJson = JSON.stringify({
    role: normalizedRole,
    role_label: roleLabel(normalizedRole),
    sdk: {
      ttl_in_secs: config.sumsubAccessTokenTtlSec,
    },
  });

  const result = await query(
    `INSERT INTO kyc_provider_cases (
         user_id,
         provider,
         external_user_id,
         level_name,
         verification_status,
         provider_review_status,
         provider_metadata,
         access_token_expires_at,
         started_at,
         created_at,
         updated_at
       )
       VALUES (
         $1,
         $2,
         $3,
         $4,
         'pending',
         'init',
         $5::jsonb,
         $6,
         now(),
         now(),
         now()
       )
       ON CONFLICT (user_id, provider)
       DO UPDATE SET
         external_user_id = EXCLUDED.external_user_id,
         level_name = EXCLUDED.level_name,
         access_token_expires_at = EXCLUDED.access_token_expires_at,
         verification_status = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.verification_status
           ELSE 'pending'
         END,
         provider_review_status = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.provider_review_status
           ELSE 'init'
         END,
         provider_review_answer = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.provider_review_answer
           ELSE NULL
         END,
         provider_review_reject_type = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.provider_review_reject_type
           ELSE NULL
         END,
         moderation_comment = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.moderation_comment
           ELSE NULL
         END,
         client_comment = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.client_comment
           ELSE NULL
         END,
         rejection_labels = CASE
           WHEN kyc_provider_cases.verification_status = 'verified'
             THEN kyc_provider_cases.rejection_labels
           ELSE NULL
         END,
         provider_metadata = COALESCE(kyc_provider_cases.provider_metadata, '{}'::jsonb) || EXCLUDED.provider_metadata,
         updated_at = now(),
         row_version = kyc_provider_cases.row_version + 1
       RETURNING
         id,
         verification_status::text AS verification_status,
         provider_review_status,
         provider_review_answer,
         provider_review_reject_type`,
    [
      userId,
      PROVIDER_NAME,
      externalUserId,
      levelName,
      metadataJson,
      expiresAt.toISOString(),
    ],
  );

  const row = result.rows[0];
  return {
    provider: PROVIDER_NAME,
    display_name: 'Secure identity check',
    access_token: tokenResponse?.token?.toString() ?? '',
    external_user_id: externalUserId,
    level_name: levelName,
    role: normalizedRole,
    role_label: roleLabel(normalizedRole),
    purpose: 'kyc',
    expires_at: expiresAt.toISOString(),
    verification_status: row?.verification_status ?? 'pending',
    review_status: row?.provider_review_status ?? 'init',
    review_answer: row?.provider_review_answer ?? null,
    review_reject_type: row?.provider_review_reject_type ?? null,
    capture_fallback_policy: 'no_fallback',
  };
}

async function refreshSumsubCaseById(providerCaseId) {
  const caseResult = await query(
    `SELECT id, external_user_id
     FROM kyc_provider_cases
     WHERE id = $1
       AND provider = $2
     LIMIT 1`,
    [providerCaseId, PROVIDER_NAME],
  );
  const providerCase = caseResult.rows[0];
  if (!providerCase) {
    throw notFound('Provider KYC case was not found.');
  }

  const applicantData = await getApplicantDataByExternalUserId(
    providerCase.external_user_id,
  );
  return updateProviderCaseFromApplicantData({
    providerCaseId: providerCase.id,
    applicantData,
    eventType: 'admin_refresh_snapshot',
    correlationId: `refresh:${providerCase.id}:${Date.now()}`,
  });
}

async function refreshLatestSumsubCaseForUser(userId) {
  const caseResult = await query(
    `SELECT id
     FROM kyc_provider_cases
     WHERE user_id = $1
       AND provider = $2
     ORDER BY updated_at DESC
     LIMIT 1`,
    [userId, PROVIDER_NAME],
  );
  const providerCaseId = caseResult.rows[0]?.id;
  if (!providerCaseId) {
    return null;
  }
  return refreshSumsubCaseById(providerCaseId);
}

async function resolveOrCreateProviderCaseId({
  externalUserId,
  providerApplicantId,
  inspectionId,
  levelName,
}) {
  const existing = await query(
    `SELECT id, user_id
       FROM kyc_provider_cases
       WHERE provider = $1
         AND (
           ($2 <> '' AND external_user_id = $2)
           OR ($3 <> '' AND provider_applicant_id = $3)
           OR ($4 <> '' AND inspection_id = $4)
         )
       ORDER BY updated_at DESC
       LIMIT 1`,
    [
      PROVIDER_NAME,
      externalUserId || '',
      providerApplicantId || '',
      inspectionId || '',
    ],
  );
  if (existing.rows[0]) {
    return existing.rows[0];
  }

  const userUuid = externalUserId?.startsWith('res:')
    ? externalUserId.slice(4)
    : '';
  if (!userUuid) {
    return null;
  }

  const userLookup = await query(
    `SELECT id
       FROM users
       WHERE uuid = $1
       LIMIT 1`,
    [userUuid],
  );
  const userId = userLookup.rows[0]?.id;
  if (!userId) {
    return null;
  }

  const inserted = await query(
    `INSERT INTO kyc_provider_cases (
         user_id,
         provider,
         external_user_id,
         provider_applicant_id,
         inspection_id,
         level_name,
         verification_status,
         provider_review_status,
         started_at,
         created_at,
         updated_at
       )
       VALUES (
         $1,
         $2,
         $3,
         NULLIF($4, ''),
         NULLIF($5, ''),
         COALESCE(NULLIF($6, ''), $2),
         'pending',
         'init',
         now(),
         now(),
         now()
       )
       ON CONFLICT (user_id, provider)
       DO UPDATE SET
         external_user_id = EXCLUDED.external_user_id,
         provider_applicant_id = COALESCE(EXCLUDED.provider_applicant_id, kyc_provider_cases.provider_applicant_id),
         inspection_id = COALESCE(EXCLUDED.inspection_id, kyc_provider_cases.inspection_id),
         level_name = COALESCE(NULLIF(EXCLUDED.level_name, $2), kyc_provider_cases.level_name),
         updated_at = now(),
         row_version = kyc_provider_cases.row_version + 1
       RETURNING id, user_id`,
    [userId, PROVIDER_NAME, externalUserId, providerApplicantId, inspectionId, levelName],
  );

  return inserted.rows[0] ?? null;
}

async function consumeSumsubWebhook({ headers, rawBody, payload }) {
  if (!isObject(payload)) {
    throw badRequest('Invalid Sumsub webhook payload.');
  }

  verifyWebhookDigest(rawBody, headers);

  const contactAction = parseContactVerificationActionId(payload.externalActionId);
  if (contactAction) {
    const correlationId = String(payload.correlationId || '').trim() || [
      payload.type || 'applicant_action',
      payload.externalActionId,
      payload.createdAtMs || payload.createdAt || Date.now(),
    ].join(':');
    const existingEvent = await query(
      `SELECT id
       FROM kyc_provider_events
       WHERE provider = $1
         AND correlation_id = $2
       LIMIT 1`,
      [PROVIDER_NAME, correlationId],
    );
    if (existingEvent.rows[0]) {
      return { accepted: true, duplicate: true, contact_channel: contactAction.channel };
    }

    const userLookup = await query(
      `SELECT id
       FROM users
       WHERE uuid = $1
       LIMIT 1`,
      [contactAction.userUuid],
    );
    const userId = userLookup.rows[0]?.id ?? null;
    const snapshot = extractApplicantActionReviewSnapshot(payload);
    const verified = userId
      ? await syncContactVerificationState({
          userId,
          channel: contactAction.channel,
          verificationStatus: snapshot.verificationStatus,
        })
      : false;

    await query(
      `INSERT INTO kyc_provider_events (
           provider_case_id,
           provider,
           correlation_id,
           event_type,
           applicant_id,
           inspection_id,
           external_user_id,
           review_status,
           review_answer,
           review_reject_type,
           payload
         )
         VALUES (
           NULL,
           $1,
           $2,
           $3,
           NULLIF($4, ''),
           NULLIF($5, ''),
           NULLIF($6, ''),
           NULLIF($7, ''),
           NULLIF($8, ''),
           NULLIF($9, ''),
           $10::jsonb
         )
         ON CONFLICT (provider, correlation_id) DO NOTHING`,
      [
        PROVIDER_NAME,
        correlationId,
        String(payload.type || 'applicantAction').trim() || 'applicantAction',
        snapshot.applicantId || '',
        String(payload.inspectionId || '').trim(),
        buildExternalUserId(contactAction.userUuid),
        snapshot.reviewStatus,
        snapshot.reviewAnswer,
        snapshot.reviewRejectType,
        JSON.stringify(payload),
      ],
    );

    return {
      accepted: true,
      duplicate: false,
      contact_channel: contactAction.channel,
      verification_status: snapshot.verificationStatus,
      verified,
    };
  }

  const eventType = String(payload.type || '').trim() || 'unknown';
  const reviewResult = isObject(payload.reviewResult) ? payload.reviewResult : {};
  const reviewStatus = String(payload.reviewStatus || '').trim() || 'init';
  const reviewAnswer = String(reviewResult.reviewAnswer || '').trim().toUpperCase() || null;
  const reviewRejectType = String(reviewResult.reviewRejectType || '').trim().toUpperCase() || null;
  const externalUserId = String(payload.externalUserId || '').trim();
  const providerApplicantId = String(payload.applicantId || '').trim();
  const inspectionId = String(payload.inspectionId || '').trim();
  const levelName = String(payload.levelName || '').trim();
  const correlationId = String(payload.correlationId || '').trim() || [
    eventType,
    externalUserId || providerApplicantId || inspectionId || 'unknown',
    payload.createdAtMs || payload.createdAt || Date.now(),
  ].join(':');
  const verificationStatus = mapReviewToVerificationStatus(reviewStatus, reviewResult);
  const eventTimestamp = parseWebhookTimestamp(payload);

  const existingEvent = await query(
    `SELECT id
       FROM kyc_provider_events
       WHERE provider = $1
         AND correlation_id = $2
       LIMIT 1`,
    [PROVIDER_NAME, correlationId],
  );
  if (existingEvent.rows[0]) {
    return { accepted: true, duplicate: true };
  }

  const providerCase = await resolveOrCreateProviderCaseId({
    externalUserId,
    providerApplicantId,
    inspectionId,
    levelName,
  });

  let applicantData = null;
  if (externalUserId) {
    try {
      applicantData = await getApplicantDataByExternalUserId(externalUserId);
    } catch (_) {
      applicantData = null;
    }
  }

  if (providerCase?.id) {
    await updateProviderCaseFromApplicantData({
      providerCaseId: providerCase.id,
      applicantData: applicantData || {
        id: providerApplicantId || null,
        inspectionId: inspectionId || null,
        externalUserId,
        levelName: levelName || null,
        review: {
          reviewStatus,
          reviewResult: {
            reviewAnswer,
            reviewRejectType,
            moderationComment: String(
              reviewResult.moderationComment || '',
            ).trim(),
            clientComment: String(reviewResult.clientComment || '').trim(),
            rejectLabels: Array.isArray(reviewResult.rejectLabels)
              ? reviewResult.rejectLabels
              : null,
          },
        },
        createdAt: payload.createdAt ?? payload.createdAtMs ?? null,
        raw_payload: payload,
      },
      eventType,
    });
  }

  await query(
    `INSERT INTO kyc_provider_events (
         provider_case_id,
         provider,
         correlation_id,
         event_type,
         applicant_id,
         inspection_id,
         external_user_id,
         review_status,
         review_answer,
         review_reject_type,
         payload
       )
       VALUES (
         $1,
         $2,
         $3,
         $4,
         NULLIF($5, ''),
         NULLIF($6, ''),
         NULLIF($7, ''),
         NULLIF($8, ''),
         NULLIF($9, ''),
         NULLIF($10, ''),
         $11::jsonb
       )`,
    [
      providerCase?.id ?? null,
      PROVIDER_NAME,
      correlationId,
      eventType,
      applicantData?.id ?? providerApplicantId,
      applicantData?.inspectionId ?? inspectionId,
      externalUserId,
      reviewStatus,
      reviewAnswer,
      reviewRejectType,
      JSON.stringify(payload),
    ],
  );

  return {
    accepted: true,
    duplicate: false,
    matched_case: providerCase?.id ?? null,
    verification_status: verificationStatus,
  };
}

module.exports = {
  PROVIDER_NAME,
  buildExternalUserId,
  buildContactVerificationActionId,
  consumeSumsubWebhook,
  createOrRefreshSumsubSession,
  createSumsubContactVerificationSession,
  refreshSumsubCaseById,
  refreshSumsubContactVerification,
  refreshLatestSumsubCaseForUser,
  getUserKycOverview,
  listUserKycRecords,
};

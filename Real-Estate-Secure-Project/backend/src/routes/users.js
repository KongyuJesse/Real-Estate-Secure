const express = require('express');

const { query, withTransaction } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest, notFound } = require('../lib/errors');
const { getPagination } = require('../lib/pagination');
const {
  canonicalizeRoles,
  hasRestrictedMobileRole,
  isAllowedMobileSelfServiceRole,
  normalizeRole,
  resolvePrimaryMobileRole,
} = require('../lib/mobile-roles');
const { requireAuth, requireRole } = require('../middleware/auth');
const { requireUserSelfOrAdmin } = require('../services/authorization-service');
const { recordPrivilegedRead } = require('../services/audit-service');
const { appendOutboxEvent } = require('../services/outbox-service');
const { getKycProviderSummary } = require('../services/kyc-provider-summary-service');
const {
  createOrRefreshSumsubSession,
  createSumsubContactVerificationSession,
  getUserKycOverview,
  listUserKycRecords,
  refreshSumsubContactVerification,
  refreshLatestSumsubCaseForUser,
} = require('../services/sumsub-kyc-service');
const { parseAssetReference, resolveAssetUrlFromReference } = require('../services/storage-service');
const { assertOptimisticLock } = require('../services/workflow-service');
const { normalizeCameroonPhoneNumber } = require('../services/cameroon-validation-service');

async function getProfileByUserId(userId) {
  const result = await query(
    `SELECT
        u.id,
        u.uuid,
        u.email,
        u.phone_number,
        u.first_name,
        u.last_name,
        u.profile_image_url,
        u.profile_image_asset_id,
        u.preferred_language,
        u.bio,
        u.is_active,
        u.row_version,
        u.two_factor_enabled,
        (u.email_verified_at IS NOT NULL) AS email_verified,
        (u.phone_verified_at IS NOT NULL) AS phone_verified,
        (u.email_verified_at IS NOT NULL OR u.phone_verified_at IS NOT NULL) AS is_verified,
        COALESCE(
          array_agg(ur.role::text ORDER BY ur.is_primary DESC, ur.role)
            FILTER (WHERE ur.role IS NOT NULL),
          ARRAY[]::text[]
        ) AS roles,
        MAX(CASE WHEN ur.is_primary THEN ur.role::text END) AS primary_role
        ,
        (
          EXISTS(
            SELECT 1
            FROM kyc_provider_cases k
            WHERE k.user_id = u.id
              AND k.provider = 'sumsub'
              AND k.verification_status = 'verified'
          )
        ) AS kyc_verified,
        COALESCE(
          (
            SELECT verification_status
            FROM kyc_provider_cases k
            WHERE k.user_id = u.id
              AND k.provider = 'sumsub'
            ORDER BY created_at DESC
            LIMIT 1
          ),
          'pending'
        ) AS kyc_status
     FROM users u
     LEFT JOIN user_roles ur ON ur.user_id = u.id
     WHERE u.id = $1
     GROUP BY u.id`,
    [userId],
  );
  if (!result.rows[0]) {
    throw notFound('User not found.');
  }
  return result.rows[0];
}

async function serializeProfile(row, req) {
  const roles = canonicalizeRoles(row.roles || []);
  const primaryRole = resolvePrimaryMobileRole(row.roles || [], row.primary_role);

  return {
    uuid: row.uuid,
    email: row.email,
    phone_number: row.phone_number,
    first_name: row.first_name,
    last_name: row.last_name,
    profile_image_url: await resolveAssetUrlFromReference(row.profile_image_url, req),
    preferred_language: row.preferred_language,
    bio: row.bio,
    roles,
    primary_role: primaryRole,
    is_active: row.is_active,
    email_verified: row.email_verified === true,
    phone_verified: row.phone_verified === true,
    is_verified: row.is_verified === true,
    kyc_verified: row.kyc_verified === true,
    kyc_status: row.kyc_status?.toString() ?? 'pending',
    two_factor_enabled: row.two_factor_enabled === true,
    row_version: row.row_version ?? 0,
  };
}

async function resolvePropertySummaryRows(rows, req) {
  return Promise.all(
    rows.map(async (row) => ({
      ...row,
      cover_image_url: await resolveAssetUrlFromReference(row.cover_image_url, req),
    })),
  );
}

function buildUsersRouter() {
  const router = express.Router();

  router.get('/profile', requireAuth, asyncHandler(async (req, res) => {
    const profile = await getProfileByUserId(req.auth.uid);
    await recordPrivilegedRead({
      req,
      userId: req.auth.uid,
      action: 'read_profile',
      entityType: 'user',
      entityId: profile.id,
      details: { user_uuid: profile.uuid },
    });
    return success(res, await serializeProfile(profile, req));
  }));

  router.put('/profile', requireAuth, asyncHandler(async (req, res) => {
    const {
      first_name,
      last_name,
      phone_number,
      preferred_language,
      bio,
      profile_image_url,
      expected_version,
    } = req.body ?? {};
    const profile = await getProfileByUserId(req.auth.uid);
    assertOptimisticLock(profile.row_version ?? 0, expected_version);
    const normalizedPhoneNumber = phone_number !== undefined && phone_number !== null
      ? normalizeCameroonPhoneNumber(phone_number)
      : null;
    const profileImageAssetUuid = parseAssetReference(profile_image_url);
    const profileImageAssetId = profileImageAssetUuid
      ? (await query('SELECT id FROM uploaded_assets WHERE uuid = $1 LIMIT 1', [profileImageAssetUuid])).rows[0]?.id ?? null
      : null;
    await query(
      `UPDATE users
       SET first_name = COALESCE($2, first_name),
           last_name = COALESCE($3, last_name),
           phone_number = COALESCE($4, phone_number),
           phone_verified_at = CASE
             WHEN $4 IS NOT NULL AND $4 <> phone_number THEN NULL
             ELSE phone_verified_at
           END,
           preferred_language = COALESCE($5, preferred_language),
           bio = COALESCE($6, bio),
           profile_image_url = COALESCE($7, profile_image_url),
           profile_image_asset_id = COALESCE($8, profile_image_asset_id),
           row_version = row_version + 1,
           updated_at = now()
        WHERE id = $1`,
      [
        req.auth.uid,
        first_name ?? null,
        last_name ?? null,
        normalizedPhoneNumber,
        preferred_language ?? null,
        bio ?? null,
        profile_image_url ?? null,
        profileImageAssetId,
      ],
    );
    await appendOutboxEvent({
      topic: 'user.profile_updated',
      aggregateType: 'user',
      aggregateId: profile.uuid,
      eventKey: `user.profile_updated:${profile.uuid}:${req.requestId}`,
      payload: {
        user_uuid: profile.uuid,
      },
    });
    return success(res, await serializeProfile(await getProfileByUserId(req.auth.uid), req));
  }));

  router.get('/tasks', requireAuth, asyncHandler(async (req, res) => {
    const { limit } = getPagination(req.query);
    const tasks = [];
    const roleResult = await query(
      `SELECT role, is_primary
       FROM user_roles
       WHERE user_id = $1
       ORDER BY is_primary DESC, created_at ASC`,
      [req.auth.uid],
    );
    const roles = canonicalizeRoles(roleResult.rows.map((row) => row.role));
    const primaryRole = resolvePrimaryMobileRole(
      roleResult.rows.map((row) => row.role),
      roleResult.rows.find((row) => row.is_primary)?.role ?? 'buyer',
    );
    const sellerLikeRoles = new Set(['seller']);

    const kycOverview = await getUserKycOverview(req.auth.uid);

    if (!kycOverview.hasAnyRecord || kycOverview.latestStatus === 'rejected') {
      tasks.push({
        code: 'complete_kyc',
        role: primaryRole,
        priority: 'high',
        title: 'Complete identity verification',
        description: 'Upload your identity document to unlock secure activity on the platform.',
        resource_type: 'user',
        resource_id: String(req.auth.uid),
        action_path: '/users/kyc/upload',
        created_at: new Date().toISOString(),
      });
    }

    if (roles.some((role) => sellerLikeRoles.has(role))) {
      const inventory = await query(
        `SELECT COUNT(*)::int AS count
         FROM properties
         WHERE owner_id = $1 OR listed_by_id = $1`,
        [req.auth.uid],
      );
      if ((inventory.rows[0]?.count ?? 0) === 0) {
        tasks.push({
          code: 'create_first_listing',
          role: primaryRole,
          priority: 'normal',
          title: 'Add your first property',
          description: 'Create a verified listing so buyers can discover your inventory.',
          resource_type: 'property',
          resource_id: '',
          action_path: '/properties',
          created_at: new Date().toISOString(),
        });
      }
    }

    if (roles.includes('lawyer')) {
      const lawyerProfile = await query(
        'SELECT id FROM lawyer_profiles WHERE user_id = $1 LIMIT 1',
        [req.auth.uid],
      );
      if (!lawyerProfile.rows[0]) {
        tasks.push({
          code: 'complete_lawyer_profile',
          role: 'lawyer',
          priority: 'high',
          title: 'Complete your lawyer profile',
          description: 'Finish your professional profile before accepting legal assignments.',
          resource_type: 'profile',
          resource_id: String(req.auth.uid),
          action_path: '/users/profile',
          created_at: new Date().toISOString(),
        });
      }
    }

    if (roles.includes('notary')) {
      const notaryProfile = await query(
        'SELECT id FROM notary_profiles WHERE user_id = $1 LIMIT 1',
        [req.auth.uid],
      );
      if (!notaryProfile.rows[0]) {
        tasks.push({
          code: 'complete_notary_profile',
          role: 'notary',
          priority: 'high',
          title: 'Complete your notary office profile',
          description: 'Add your office details before coordinating closings on the platform.',
          resource_type: 'profile',
          resource_id: String(req.auth.uid),
          action_path: '/users/profile',
          created_at: new Date().toISOString(),
        });
      }
    }

    const deals = await query(
      `SELECT uuid, transaction_status, created_at, buyer_id, seller_id, lawyer_id, notary_id
       FROM transactions
       WHERE buyer_id = $1 OR seller_id = $1 OR lawyer_id = $1 OR notary_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [req.auth.uid, limit],
    );
    deals.rows.forEach((row) => {
      const authUserId = String(req.auth.uid);
      const isBuyerSide = String(row.buyer_id ?? '') === authUserId;
      const isSellerSide = String(row.seller_id ?? '') === authUserId;
      const isLawyerSide = String(row.lawyer_id ?? '') === authUserId;
      const isNotarySide = String(row.notary_id ?? '') === authUserId;
      const title = isLawyerSide
        ? `Legal file ${String(row.transaction_status).replaceAll('_', ' ')}`
        : isNotarySide
          ? `Closing file ${String(row.transaction_status).replaceAll('_', ' ')}`
          : isSellerSide
            ? `Sale file ${String(row.transaction_status).replaceAll('_', ' ')}`
            : isBuyerSide
              ? `Purchase file ${String(row.transaction_status).replaceAll('_', ' ')}`
              : `Transaction ${String(row.transaction_status).replaceAll('_', ' ')}`;
      const description = isLawyerSide
        ? 'Review legal requirements, evidence, and next case actions.'
        : isNotarySide
          ? 'Track the notarial file and the next closing milestone.'
          : isSellerSide
            ? 'Check what the buyer, notary, or legal team needs next.'
            : isBuyerSide
              ? 'Review the current stage and the next step for your file.'
              : 'Review the current closing stage and next actions.';

      tasks.push({
        code: `transaction_${row.transaction_status}`,
        role: primaryRole,
        priority: ['disputed', 'cancelled'].includes(row.transaction_status) ? 'high' : 'normal',
        title,
        description,
        resource_type: 'transaction',
        resource_id: row.uuid,
        action_path: `/transactions/${row.uuid}`,
        created_at: row.created_at,
      });
    });

    return success(res, tasks.slice(0, limit));
  }));

  router.post('/kyc/upload', requireAuth, asyncHandler(async (req, res) => {
    throw badRequest(
      'Manual KYC upload has been retired. Use the Sumsub verification flow instead.',
    );
  }));

  router.post('/kyc/session', requireAuth, asyncHandler(async (req, res) => {
    const profile = await getProfileByUserId(req.auth.uid);
    const primaryRole = resolvePrimaryMobileRole(
      profile.roles || [],
      profile.primary_role,
    );
    const session = await createOrRefreshSumsubSession({
      userId: req.auth.uid,
      userUuid: profile.uuid,
      email: profile.email,
      phone: profile.phone_number,
      role: primaryRole,
    });
    return success(res, session, undefined, 201);
  }));

  router.get('/kyc/status', requireAuth, asyncHandler(async (req, res) => {
    return success(res, await listUserKycRecords(req.auth.uid));
  }));

  router.post('/kyc/refresh', requireAuth, asyncHandler(async (req, res) => {
    const providerCase = await refreshLatestSumsubCaseForUser(req.auth.uid);
    return success(res, {
      refreshed: providerCase !== null,
      provider_case: providerCase,
      records: await listUserKycRecords(req.auth.uid),
    });
  }));

  router.get('/kyc/provider-summary', requireAuth, asyncHandler(async (req, res) => {
    const profile = await getProfileByUserId(req.auth.uid);
    return success(
      res,
      getKycProviderSummary({
        role: resolvePrimaryMobileRole(profile.roles || [], profile.primary_role),
      }),
    );
  }));

  router.post('/contact-verification/session', requireAuth, asyncHandler(async (req, res) => {
    const channel = String(req.body?.channel || '').trim().toLowerCase();
    if (!['email', 'phone'].includes(channel)) {
      throw badRequest('channel must be email or phone.');
    }

    const profile = await getProfileByUserId(req.auth.uid);
    if (channel === 'email') {
      if (!profile.email) {
        throw badRequest('An email address is required before verification can start.');
      }
      if (profile.email_verified === true) {
        return success(res, { already_verified: true, channel });
      }
    } else {
      if (!profile.phone_number) {
        throw badRequest('A phone number is required before verification can start.');
      }
      if (profile.phone_verified === true) {
        return success(res, { already_verified: true, channel });
      }
    }

    const session = await createSumsubContactVerificationSession({
      userId: req.auth.uid,
      userUuid: profile.uuid,
      channel,
    });
    return success(res, session, undefined, 201);
  }));

  router.post('/contact-verification/refresh', requireAuth, asyncHandler(async (req, res) => {
    const channel = String(req.body?.channel || '').trim().toLowerCase();
    if (!['email', 'phone'].includes(channel)) {
      throw badRequest('channel must be email or phone.');
    }

    const profile = await getProfileByUserId(req.auth.uid);
    const contactStatus = await refreshSumsubContactVerification({
      userId: req.auth.uid,
      userUuid: profile.uuid,
      channel,
      externalActionId: req.body?.external_action_id,
    });
    const refreshedProfile = await getProfileByUserId(req.auth.uid);
    return success(res, {
      ...contactStatus,
      email_verified: refreshedProfile.email_verified === true,
      phone_verified: refreshedProfile.phone_verified === true,
    });
  }));

  router.get('/roles', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT role, is_primary, verified_at, expires_at, metadata
       FROM user_roles
       WHERE user_id = $1
       ORDER BY created_at ASC`,
      [req.auth.uid],
    );
    return success(res, result.rows);
  }));

  router.post('/roles', requireAuth, asyncHandler(async (req, res) => {
    if (!req.body?.role) {
      throw badRequest('role is required.');
    }
    const role = normalizeRole(req.body.role);
    if (!isAllowedMobileSelfServiceRole(role)) {
      throw badRequest('This role cannot be added from the Android app.');
    }
    await query(
      `INSERT INTO user_roles (user_id, role, is_primary)
       VALUES ($1, $2, false)
       ON CONFLICT (user_id, role) DO NOTHING`,
      [req.auth.uid, canonicalizeRoles([role])[0]],
    );
    return success(res, { role_added: canonicalizeRoles([role])[0] }, undefined, 201);
  }));

  router.put('/roles/primary', requireAuth, asyncHandler(async (req, res) => {
    if (!req.body?.role) {
      throw badRequest('role is required.');
    }
    const role = canonicalizeRoles([normalizeRole(req.body.role)])[0];
    if (!role || !isAllowedMobileSelfServiceRole(role)) {
      throw badRequest('This role cannot be activated from the Android app.');
    }
    if (hasRestrictedMobileRole([role])) {
      throw badRequest('This role cannot be activated from the Android app.');
    }
    await withTransaction(async (client) => {
      await client.query('UPDATE user_roles SET is_primary = false WHERE user_id = $1', [req.auth.uid]);
      await client.query('UPDATE user_roles SET is_primary = true WHERE user_id = $1 AND role = $2', [req.auth.uid, role]);
    });
    return success(res, { primary_role: role });
  }));

  router.put('/preferences', requireAuth, asyncHandler(async (req, res) => {
    const {
      locale,
      email_notifications_enabled,
      sms_notifications_enabled,
      push_notifications_enabled,
      marketing_notifications_enabled,
    } = req.body ?? {};

    await query(
      `INSERT INTO user_preferences (
          user_id, locale, email_notifications_enabled, sms_notifications_enabled,
          push_notifications_enabled, marketing_notifications_enabled, updated_at
       )
       VALUES ($1,$2,COALESCE($3,true),COALESCE($4,true),COALESCE($5,true),COALESCE($6,false),now())
       ON CONFLICT (user_id)
       DO UPDATE SET
         locale = COALESCE(EXCLUDED.locale, user_preferences.locale),
         email_notifications_enabled = COALESCE(EXCLUDED.email_notifications_enabled, user_preferences.email_notifications_enabled),
         sms_notifications_enabled = COALESCE(EXCLUDED.sms_notifications_enabled, user_preferences.sms_notifications_enabled),
         push_notifications_enabled = COALESCE(EXCLUDED.push_notifications_enabled, user_preferences.push_notifications_enabled),
         marketing_notifications_enabled = COALESCE(EXCLUDED.marketing_notifications_enabled, user_preferences.marketing_notifications_enabled),
         updated_at = now()`,
      [req.auth.uid, locale ?? null, email_notifications_enabled ?? null, sms_notifications_enabled ?? null, push_notifications_enabled ?? null, marketing_notifications_enabled ?? null],
    );
    return success(res, { updated: true });
  }));

  router.get('/preferences', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT
          locale,
          email_notifications_enabled,
          sms_notifications_enabled,
          push_notifications_enabled,
          marketing_notifications_enabled,
          updated_at
       FROM user_preferences
       WHERE user_id = $1
       LIMIT 1`,
      [req.auth.uid],
    );

    const preferences = result.rows[0] ?? {
      locale: 'en',
      email_notifications_enabled: true,
      sms_notifications_enabled: true,
      push_notifications_enabled: true,
      marketing_notifications_enabled: false,
      updated_at: null,
    };

    return success(res, preferences);
  }));

  router.get('/favorites', requireAuth, asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT
          p.uuid AS id,
          p.title,
          p.price AS price_xaf,
          p.property_type AS type,
          p.listing_type,
          p.is_featured,
          p.property_status AS status,
          p.verification_status,
          p.risk_lane,
          p.admission_status,
          pi.file_path_original AS cover_image_url,
          pl.city,
          pl.region
       FROM favorites f
       JOIN properties p ON p.id = f.property_id
       LEFT JOIN LATERAL (
         SELECT file_path_original
         FROM property_images
         WHERE property_id = p.id
         ORDER BY is_primary DESC, sort_order ASC, created_at ASC
         LIMIT 1
       ) pi ON true
       LEFT JOIN LATERAL (
         SELECT city, region
         FROM property_locations
         WHERE property_id = p.id
         ORDER BY CASE WHEN location_type::text = 'primary' THEN 0 ELSE 1 END, id ASC
         LIMIT 1
       ) pl ON true
       WHERE f.user_id = $1
         AND p.deleted_at IS NULL
       ORDER BY f.created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.auth.uid, limit, offset],
    );
    return success(res, await resolvePropertySummaryRows(result.rows, req), {
      page,
      limit,
      count: result.rows.length,
    });
  }));

  router.delete('/account', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE users
       SET is_active = false, deleted_at = now(), updated_at = now()
       WHERE id = $1`,
      [req.auth.uid],
    );
    return success(res, { deleted: true });
  }));

  router.get('/:id/listings', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT p.uuid AS id, p.title, pl.city, pl.region, p.price AS price_xaf,
              p.property_type AS type, p.listing_type, p.is_featured,
              p.property_status AS status, p.verification_status, p.risk_lane, p.admission_status,
              pi.file_path_original AS cover_image_url
       FROM properties p
       LEFT JOIN LATERAL (
         SELECT file_path_original
         FROM property_images
         WHERE property_id = p.id
         ORDER BY is_primary DESC, sort_order ASC, created_at ASC
         LIMIT 1
       ) pi ON true
       LEFT JOIN LATERAL (
         SELECT city, region
         FROM property_locations
         WHERE property_id = p.id
         ORDER BY id ASC
         LIMIT 1
       ) pl ON true
       WHERE p.owner_id = (SELECT id FROM users WHERE uuid = $1)
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.params.id, limit, offset],
    );
    return success(res, await resolvePropertySummaryRows(result.rows, req), {
      page,
      limit,
      count: result.rows.length,
    });
  }));

  router.get('/:id/transactions', requireAuth, asyncHandler(async (req, res) => {
    await requireUserSelfOrAdmin(req, req.params.id);
    const { limit, offset, page } = getPagination(req.query);
    const userLookup = await query(
      'SELECT id, uuid FROM users WHERE uuid = $1 LIMIT 1',
      [req.params.id],
    );
    if (!userLookup.rows[0]) {
      throw notFound('User not found.');
    }
    const result = await query(
      `SELECT uuid, transaction_number, transaction_status, total_amount, currency, created_at
       FROM transactions
       WHERE buyer_id = (SELECT id FROM users WHERE uuid = $1)
          OR seller_id = (SELECT id FROM users WHERE uuid = $1)
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.params.id, limit, offset],
    );
    await recordPrivilegedRead({
      req,
      userId: req.auth.uid,
      action: 'read_user_transactions',
      entityType: 'user',
      entityId: userLookup.rows[0].id,
      details: { user_uuid: userLookup.rows[0].uuid },
    });
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/:id/reviews', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT rating, title, review_text, created_at
       FROM lawyer_reviews
       WHERE reviewer_id = (SELECT id FROM users WHERE uuid = $1)
       ORDER BY created_at DESC`,
      [req.params.id],
    );
    return success(res, result.rows);
  }));

  router.get('/:id', requireAuth, asyncHandler(async (req, res) => {
    await requireUserSelfOrAdmin(req, req.params.id);
    const result = await query(
      `SELECT uuid, email, first_name, last_name, is_active
       FROM users
       WHERE uuid = $1`,
      [req.params.id],
    );
    if (!result.rows[0]) {
      throw notFound('User not found.');
    }
    return success(res, result.rows[0]);
  }));

  router.get('/', requireAuth, requireRole('admin', 'super_admin'), asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT uuid, email, first_name, last_name, is_active, created_at
       FROM users
       ORDER BY created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  return router;
}

module.exports = { buildUsersRouter };

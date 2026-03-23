const express = require('express');

const { query, withTransaction } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest, notFound } = require('../lib/errors');
const { getPagination } = require('../lib/pagination');
const { requireAuth } = require('../middleware/auth');
const { requirePropertyOwnership } = require('../services/authorization-service');
const { appendOutboxEvent } = require('../services/outbox-service');
const { withIdempotency } = require('../services/idempotency-service');
const {
  getAssetRecord,
  parseAssetReference,
  resolveAssetUrlFromReference,
} = require('../services/storage-service');
const { evaluatePropertyAdmission } = require('../services/property-admission-service');
const {
  listCameroonAdministrativeCatalog,
  validateCameroonPropertyLocation,
} = require('../services/cameroon-validation-service');
const {
  assertClosingStateUpdate,
  assertOptimisticLock,
} = require('../services/workflow-service');

const allowedPropertyTypes = new Set([
  'land',
  'house',
  'apartment',
  'commercial',
  'industrial',
  'agricultural',
]);

const allowedListingTypes = new Set(['sale', 'rent', 'lease']);

function buildAdmissionProfile({ listingType, admission }) {
  return {
    listing_type: listingType,
    risk_lane: admission.riskLane,
    admission_status: admission.admissionStatus,
    marketplace_eligible: admission.marketplaceEligible,
    missing_documents: admission.missingDocuments,
    notes: admission.notes,
  };
}

const summarySelect = `
  SELECT
    p.id,
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
    ORDER BY CASE WHEN location_type::text = 'primary' THEN 0 ELSE 1 END, id ASC
    LIMIT 1
  ) pl ON true
`;

async function findOwnedPropertyId(propertyUuid, userId) {
  const property = await query(
    `SELECT id
     FROM properties
     WHERE uuid = $1
       AND deleted_at IS NULL
       AND (owner_id = $2 OR listed_by_id = $2)
     LIMIT 1`,
    [propertyUuid, userId],
  );
  if (!property.rows[0]) {
    throw notFound('Property not found.');
  }
  return property.rows[0].id;
}

async function resolveAssetIdFromReference(reference) {
  const assetUuid = parseAssetReference(reference);
  if (!assetUuid) {
    return null;
  }
  const result = await query('SELECT id FROM uploaded_assets WHERE uuid = $1 LIMIT 1', [assetUuid]);
  return result.rows[0]?.id ?? null;
}

async function assertOwnedAssetReference(reference, ownerUserId, allowedCategories) {
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
  if (allowedCategories && !allowedCategories.includes(String(asset.category))) {
    throw badRequest('Uploaded asset category is not valid for this operation.');
  }
  if (String(asset.malware_scan_status) === 'rejected') {
    throw badRequest('Uploaded asset failed security scanning and cannot be attached.');
  }
  return asset;
}

async function resolveSummaryRows(rows, req) {
  return Promise.all(
    rows.map(async (row) => ({
      ...row,
      cover_image_url: await resolveAssetUrlFromReference(row.cover_image_url, req),
    })),
  );
}

function buildPropertiesRouter() {
  const router = express.Router();

  router.get('/', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const featuredOnly = String(req.query.featured || '').toLowerCase() === 'true';
    const result = await query(
      `${summarySelect}
       WHERE p.deleted_at IS NULL
         AND p.property_status = 'active'
          AND ($1::boolean = false OR p.is_featured = true)
        ORDER BY p.is_featured DESC, p.created_at DESC
        LIMIT $2 OFFSET $3`,
      [featuredOnly, limit, offset],
    );
    return success(res, await resolveSummaryRows(result.rows, req), { page, limit, count: result.rows.length });
  }));

  router.get('/search', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const search = `%${String(req.query.q || '').trim()}%`;
    const result = await query(
      `${summarySelect}
       WHERE p.deleted_at IS NULL
         AND p.property_status = 'active'
          AND ($1 = '%%'
               OR p.title ILIKE $1
               OR p.description ILIKE $1
              OR COALESCE(pl.city, '') ILIKE $1
              OR COALESCE(pl.region, '') ILIKE $1)
       ORDER BY p.is_featured DESC, p.created_at DESC
        LIMIT $2 OFFSET $3`,
      [search, limit, offset],
    );
    return success(res, await resolveSummaryRows(result.rows, req), { page, limit, count: result.rows.length });
  }));

  router.get('/map', asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT
          p.uuid AS id,
          p.title,
          p.price,
          p.currency,
          pl.latitude,
          pl.longitude,
          pl.city,
          pl.region
       FROM properties p
        JOIN property_locations pl
          ON pl.property_id = p.id
         AND pl.location_type = 'primary'
        WHERE p.deleted_at IS NULL
         AND p.property_status = 'active'
         AND COALESCE(pl.is_public, false) = true
        ORDER BY p.is_featured DESC, p.created_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.get('/location-catalog/cameroon', asyncHandler(async (req, res) => {
    const regions = await listCameroonAdministrativeCatalog();
    return success(res, {
      country: 'Cameroon',
      regions,
    });
  }));

  router.get('/:id', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT
          p.uuid AS id,
          p.title,
          p.description,
          p.property_type,
          p.listing_type,
          p.price,
          p.currency,
          p.property_status AS status,
          p.verification_status,
          p.is_featured,
          p.inventory_type,
          p.risk_lane,
          p.admission_status,
          owner.uuid AS owner_uuid,
          CONCAT(owner.first_name, ' ', owner.last_name) AS owner_name,
          p.seller_identity_verified_snapshot,
          p.declared_encumbrance,
          p.declared_dispute,
          p.foreign_party_expected,
          p.old_title_risk,
          p.court_linked,
          p.ministry_filing_required,
          p.municipal_certificate_required,
          json_build_object(
            'country', pl.country,
           'region', pl.region,
           'department', pl.department,
           'city', pl.city,
           'district', pl.district,
           'neighborhood', pl.neighborhood,
           'street_address', CASE WHEN pl.is_public THEN pl.street_address ELSE NULL END,
           'landmark', pl.landmark,
           'latitude', CASE WHEN pl.is_public THEN pl.latitude ELSE NULL END,
           'longitude', CASE WHEN pl.is_public THEN pl.longitude ELSE NULL END
          ) AS location
       FROM properties p
       LEFT JOIN users owner ON owner.id = p.owner_id
       LEFT JOIN LATERAL (
         SELECT *
         FROM property_locations
         WHERE property_id = p.id
         ORDER BY CASE WHEN location_type::text = 'primary' THEN 0 ELSE 1 END, id ASC
         LIMIT 1
       ) pl ON true
       WHERE p.uuid = $1
         AND p.deleted_at IS NULL
         AND p.property_status = 'active'
       LIMIT 1`,
      [req.params.id],
    );
    if (!result.rows[0]) {
      throw notFound('Property not found.');
    }
    return success(res, result.rows[0]);
  }));

  router.get('/:id/status', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT uuid AS id, property_status, verification_status, risk_lane, admission_status
       FROM properties
       WHERE uuid = $1`,
      [req.params.id],
    );
    if (!result.rows[0]) {
      throw notFound('Property not found.');
    }
    return success(res, result.rows[0]);
  }));

  router.post('/', requireAuth, withIdempotency(), asyncHandler(async (req, res) => {
    const {
      property_type,
      listing_type,
      title,
      description,
      price,
      currency = 'XAF',
      region,
      department,
      city,
      district,
      neighborhood,
      street_address,
      landmark,
      latitude,
      longitude,
      inventory_type = 'titled_private',
      declared_encumbrance = false,
      declared_dispute = false,
      foreign_party_expected = false,
      old_title_risk = false,
      court_linked = false,
      ministry_filing_required = false,
      municipal_certificate_required = false,
    } = req.body ?? {};

    if (!property_type || !listing_type || !title || !description || !price || !region || !department || !city || latitude === undefined || longitude === undefined) {
      throw badRequest('property_type, listing_type, title, description, price, region, department, city, latitude, and longitude are required.');
    }

    if (!allowedPropertyTypes.has(String(property_type).trim())) {
      throw badRequest('Unsupported property_type value.');
    }
    if (!allowedListingTypes.has(String(listing_type).trim())) {
      throw badRequest('Unsupported listing_type value.');
    }
    if (!Number.isFinite(Number(price)) || Number(price) <= 0) {
      throw badRequest('price must be a positive number.');
    }

    const normalizedLocation = await validateCameroonPropertyLocation({
      region,
      department,
      latitude,
      longitude,
    });
    const ownerIdentity = await query(
      `SELECT (email_verified_at IS NOT NULL OR phone_verified_at IS NOT NULL) AS is_verified
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [req.auth.uid],
    );
    const sellerIdentityVerifiedSnapshot = ownerIdentity.rows[0]?.is_verified === true;
    const admission = evaluatePropertyAdmission({
      listingType: listing_type,
      inventoryType: listing_type === 'sale' ? inventory_type : null,
      sellerIdentityVerifiedSnapshot,
      declaredEncumbrance: declared_encumbrance === true,
      declaredDispute: declared_dispute === true,
      foreignPartyExpected: foreign_party_expected === true,
      oldTitleRisk: old_title_risk === true,
      courtLinked: court_linked === true,
      ministryFilingRequired: ministry_filing_required === true,
      municipalCertificateRequired: municipal_certificate_required === true,
      documentTypes: [],
    });

    const property = await withTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO properties (
            owner_id, listed_by_id, property_type, listing_type, title,
            description, price, currency, property_status, verification_status,
            inventory_type, risk_lane, admission_status, admission_profile,
            seller_identity_verified_snapshot, declared_encumbrance, declared_dispute,
            foreign_party_expected, old_title_risk, court_linked,
            ministry_filing_required, municipal_certificate_required
         )
         VALUES ($1,$1,$2,$3,$4,$5,$6,$7,'draft','pending',$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
         RETURNING id, uuid`,
        [
          req.auth.uid,
          property_type,
          listing_type,
          title,
          description,
          price,
          currency,
          listing_type === 'sale' ? inventory_type : null,
          admission.riskLane,
          admission.admissionStatus,
          JSON.stringify(buildAdmissionProfile({ listingType: listing_type, admission })),
          sellerIdentityVerifiedSnapshot,
          declared_encumbrance === true,
          declared_dispute === true,
          foreign_party_expected === true,
          old_title_risk === true,
          court_linked === true,
          ministry_filing_required === true,
          municipal_certificate_required === true,
        ],
      );
      const row = inserted.rows[0];
      await client.query(
        `INSERT INTO property_locations (
            property_id, location_type, region, department, city, district,
            neighborhood, street_address, landmark, latitude, longitude
         )
         VALUES ($1,'primary',$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [
          row.id,
          normalizedLocation.region,
          normalizedLocation.department,
          city,
          district ?? null,
          neighborhood ?? null,
          street_address ?? null,
          landmark ?? null,
          normalizedLocation.latitude,
          normalizedLocation.longitude,
        ],
      );
      return row;
    });

    await appendOutboxEvent({
      topic: 'property.created',
      aggregateType: 'property',
      aggregateId: property.uuid,
      eventKey: `property.created:${property.uuid}:${req.requestId}`,
      payload: {
        property_uuid: property.uuid,
        owner_user_id: req.auth.uid,
        inventory_type,
      },
    });

    return success(res, { id: property.uuid }, undefined, 201);
  }));

  router.put('/:id', requireAuth, withIdempotency(), asyncHandler(async (req, res) => {
    const current = await requirePropertyOwnership(req, req.params.id);
    const {
      title,
      description,
      price,
      property_status,
      commercial_close_status,
      notarial_execution_status,
      title_confirmation_status,
      expected_version,
    } = req.body ?? {};
    assertOptimisticLock(current.row_version ?? 0, expected_version);
    assertClosingStateUpdate(current.commercial_close_status, commercial_close_status, 'commercial_close_status');
    assertClosingStateUpdate(current.notarial_execution_status, notarial_execution_status, 'notarial_execution_status');
    assertClosingStateUpdate(current.title_confirmation_status, title_confirmation_status, 'title_confirmation_status');
    const result = await query(
      `UPDATE properties
       SET title = COALESCE($2, title),
           description = COALESCE($3, description),
           price = COALESCE($4, price),
           property_status = COALESCE($5, property_status),
           commercial_close_status = COALESCE($6, commercial_close_status),
           notarial_execution_status = COALESCE($7, notarial_execution_status),
           title_confirmation_status = COALESCE($8, title_confirmation_status),
           row_version = row_version + 1,
           updated_at = now()
       WHERE uuid = $1
         AND (owner_id = $9 OR listed_by_id = $9)
         AND row_version = $10
       RETURNING uuid AS id, title, property_status AS status, row_version`,
      [
        req.params.id,
        title ?? null,
        description ?? null,
        price ?? null,
        property_status ?? null,
        commercial_close_status ?? null,
        notarial_execution_status ?? null,
        title_confirmation_status ?? null,
        req.auth.uid,
        current.row_version ?? 0,
      ],
    );
    if (!result.rows[0]) {
      throw notFound('Property not found.');
    }
    await appendOutboxEvent({
      topic: 'property.updated',
      aggregateType: 'property',
      aggregateId: req.params.id,
      eventKey: `property.updated:${req.params.id}:${req.requestId}`,
      payload: {
        property_uuid: req.params.id,
        row_version: result.rows[0].row_version,
      },
    });
    return success(res, result.rows[0]);
  }));

  router.delete('/:id', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE properties SET deleted_at = now(), updated_at = now()
       WHERE uuid = $1 AND owner_id = $2`,
      [req.params.id, req.auth.uid],
    );
    return success(res, { deleted: true });
  }));

  router.get('/:id/documents', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, document_type, document_title, is_verified, issue_date, expiry_date
       FROM property_documents
       WHERE property_id = (SELECT id FROM properties WHERE uuid = $1)
         AND is_public = true
        ORDER BY created_at DESC`,
      [req.params.id],
    );
    return success(res, result.rows);
  }));

  router.get('/:id/images', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, image_type, title, description, is_primary, sort_order, file_path_original, mime_type
       FROM property_images
       WHERE property_id = (SELECT id FROM properties WHERE uuid = $1)
       ORDER BY is_primary DESC, sort_order ASC, created_at ASC`,
      [req.params.id],
    );
    return success(
      res,
      await Promise.all(
        result.rows.map(async (row) => ({
          ...row,
          file_path_original: await resolveAssetUrlFromReference(row.file_path_original, req),
        })),
      ),
    );
  }));

  router.post('/:id/images', requireAuth, withIdempotency(), asyncHandler(async (req, res) => {
    const {
      file_path_original,
      mime_type,
      file_hash = '',
      file_size = 0,
      image_type = 'exterior',
      title,
      description,
    } = req.body ?? {};
    if (!file_path_original || !mime_type) {
      throw badRequest('file_path_original and mime_type are required.');
    }
    const propertyId = await findOwnedPropertyId(req.params.id, req.auth.uid);
    await assertOwnedAssetReference(file_path_original, req.auth.uid, ['property_image']);
    const assetId = await resolveAssetIdFromReference(file_path_original);
    const result = await query(
      `INSERT INTO property_images (
          property_id, image_type, title, description, file_path_original, file_hash, file_size, mime_type, original_asset_id
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING id, image_type, title, file_path_original`,
      [propertyId, image_type, title ?? null, description ?? null, file_path_original, file_hash, file_size, mime_type, assetId],
    );
    await appendOutboxEvent({
      topic: 'property.image_added',
      aggregateType: 'property',
      aggregateId: req.params.id,
      eventKey: `property.image_added:${req.params.id}:${result.rows[0].id}:${req.requestId}`,
      payload: {
        property_uuid: req.params.id,
        image_id: result.rows[0].id,
        image_type,
      },
    });
    return success(res, result.rows[0], undefined, 201);
  }));

  router.delete('/:id/images/:imageId', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `DELETE FROM property_images
       WHERE id = $1
         AND property_id = (
           SELECT id FROM properties
           WHERE uuid = $2
             AND (owner_id = $3 OR listed_by_id = $3)
         )`,
      [req.params.imageId, req.params.id, req.auth.uid],
    );
    return success(res, { deleted: true });
  }));

  router.post('/:id/documents', requireAuth, withIdempotency(), asyncHandler(async (req, res) => {
    const {
      document_type,
      document_number,
      document_title,
      issuing_authority,
      issue_date,
      expiry_date,
      file_path,
      mime_type,
      file_hash = '',
      file_size = 0,
    } = req.body ?? {};
    if (!document_type || !document_number || !document_title || !issuing_authority || !issue_date || !file_path || !mime_type) {
      throw badRequest('Missing required property document fields.');
    }
    const propertyId = await findOwnedPropertyId(req.params.id, req.auth.uid);
    await assertOwnedAssetReference(file_path, req.auth.uid, ['property_document']);
    const assetId = await resolveAssetIdFromReference(file_path);
    const result = await query(
      `INSERT INTO property_documents (
          property_id, document_type, document_number, document_title, issuing_authority,
          issue_date, expiry_date, file_path, file_hash, file_size, mime_type, asset_id
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING id, document_type, document_number, is_verified`,
      [
        propertyId,
        document_type,
        document_number,
        document_title,
        issuing_authority,
        issue_date,
        expiry_date ?? null,
        file_path,
        file_hash,
        file_size,
        mime_type,
        assetId,
      ],
    );
    const property = await query(
      `SELECT p.*, (u.email_verified_at IS NOT NULL OR u.phone_verified_at IS NOT NULL) AS seller_identity_verified
       FROM properties p
       JOIN users u ON u.id = p.owner_id
       WHERE p.id = $1`,
      [propertyId],
    );
    const documentResult = await query(
      `SELECT document_type
       FROM property_documents
       WHERE property_id = $1`,
      [propertyId],
    );
    const admission = evaluatePropertyAdmission({
      listingType: property.rows[0].listing_type,
      inventoryType: property.rows[0].inventory_type,
      sellerIdentityVerifiedSnapshot: property.rows[0].seller_identity_verified === true,
      declaredEncumbrance: property.rows[0].declared_encumbrance === true,
      declaredDispute: property.rows[0].declared_dispute === true,
      foreignPartyExpected: property.rows[0].foreign_party_expected === true,
      oldTitleRisk: property.rows[0].old_title_risk === true,
      courtLinked: property.rows[0].court_linked === true,
      ministryFilingRequired: property.rows[0].ministry_filing_required === true,
      municipalCertificateRequired: property.rows[0].municipal_certificate_required === true,
      documentTypes: documentResult.rows.map((row) => row.document_type),
    });
    await query(
      `UPDATE properties
       SET risk_lane = $2,
           admission_status = $3,
           admission_profile = $4,
           seller_identity_verified_snapshot = $5,
           updated_at = now()
       WHERE id = $1`,
      [
        propertyId,
        admission.riskLane,
        admission.admissionStatus,
        JSON.stringify(buildAdmissionProfile({ listingType: property.rows[0].listing_type, admission })),
        property.rows[0].seller_identity_verified === true,
      ],
    );
    await appendOutboxEvent({
      topic: 'property.document_added',
      aggregateType: 'property',
      aggregateId: req.params.id,
      eventKey: `property.document_added:${req.params.id}:${result.rows[0].id}:${req.requestId}`,
      payload: {
        property_uuid: req.params.id,
        document_id: result.rows[0].id,
        document_type,
      },
    });
    return success(res, result.rows[0], undefined, 201);
  }));

  router.post('/:id/verify', requireAuth, asyncHandler(async (req, res) => {
    const property = await query(
      `SELECT p.*, (u.email_verified_at IS NOT NULL OR u.phone_verified_at IS NOT NULL) AS seller_identity_verified
       FROM properties p
       JOIN users u ON u.id = p.owner_id
       WHERE p.uuid = $1
         AND (p.owner_id = $2 OR p.listed_by_id = $2)
       LIMIT 1`,
      [req.params.id, req.auth.uid],
    );
    if (!property.rows[0]) {
      throw notFound('Property not found.');
    }
    const documentResult = await query(
      `SELECT document_type
       FROM property_documents
       WHERE property_id = $1`,
      [property.rows[0].id],
    );
    const admission = evaluatePropertyAdmission({
      listingType: property.rows[0].listing_type,
      inventoryType: property.rows[0].inventory_type,
      sellerIdentityVerifiedSnapshot: property.rows[0].seller_identity_verified === true,
      declaredEncumbrance: property.rows[0].declared_encumbrance === true,
      declaredDispute: property.rows[0].declared_dispute === true,
      foreignPartyExpected: property.rows[0].foreign_party_expected === true,
      oldTitleRisk: property.rows[0].old_title_risk === true,
      courtLinked: property.rows[0].court_linked === true,
      ministryFilingRequired: property.rows[0].ministry_filing_required === true,
      municipalCertificateRequired: property.rows[0].municipal_certificate_required === true,
      documentTypes: documentResult.rows.map((row) => row.document_type),
    });

    if (property.rows[0].listing_type === 'sale' && admission.riskLane === 'blocked') {
      throw badRequest('This property cannot be submitted to the marketplace sale lane.', {
        notes: admission.notes,
      });
    }
    if (
      property.rows[0].listing_type === 'sale' &&
      admission.riskLane === 'government_light' &&
      !admission.marketplaceEligible
    ) {
      throw badRequest('Required sale admission evidence is missing before verification submission.', {
        missing_documents: admission.missingDocuments,
        notes: admission.notes,
      });
    }

    const updated = await query(
      `UPDATE properties
       SET property_status = 'pending',
           verification_status = 'pending',
           risk_lane = $3,
           admission_status = $4,
           admission_profile = $5,
           seller_identity_verified_snapshot = $6,
           updated_at = now()
       WHERE uuid = $1
         AND (owner_id = $2 OR listed_by_id = $2)
       RETURNING uuid`,
      [
        req.params.id,
        req.auth.uid,
        admission.riskLane,
        admission.admissionStatus,
        JSON.stringify(buildAdmissionProfile({ listingType: property.rows[0].listing_type, admission })),
        property.rows[0].seller_identity_verified === true,
      ],
    );
    await appendOutboxEvent({
      topic: 'property.verification_submitted',
      aggregateType: 'property',
      aggregateId: req.params.id,
      eventKey: `property.verification_submitted:${req.params.id}:${req.requestId}`,
      payload: {
        property_uuid: req.params.id,
      },
    });
    return success(res, { submitted: true, property_id: req.params.id });
  }));

  router.post('/:id/favorite', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `INSERT INTO favorites (user_id, property_id)
       VALUES ($1, (SELECT id FROM properties WHERE uuid = $2))
       ON CONFLICT (user_id, property_id) DO NOTHING`,
      [req.auth.uid, req.params.id],
    );
    return success(res, { favorited: true });
  }));

  router.delete('/:id/favorite', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `DELETE FROM favorites
       WHERE user_id = $1 AND property_id = (SELECT id FROM properties WHERE uuid = $2)`,
      [req.auth.uid, req.params.id],
    );
    return success(res, { favorited: false });
  }));

  router.post('/:id/report', requireAuth, asyncHandler(async (req, res) => success(res, {
    reported: true,
    property_id: req.params.id,
    note: req.body?.note ?? null,
  }, undefined, 202)));

  return router;
}

module.exports = { buildPropertiesRouter };

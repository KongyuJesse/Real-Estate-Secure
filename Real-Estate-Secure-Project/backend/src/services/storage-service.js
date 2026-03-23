const crypto = require('crypto');
const fs = require('fs');
const fsPromises = require('fs/promises');
const path = require('path');

const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { fileTypeFromBuffer } = require('file-type');
const mime = require('mime-types');

const { query } = require('../db');
const { config } = require('../config');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const { scanBufferForMalware } = require('./malware-scan-service');

const imageMimeTypes = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);

const documentMimeTypes = new Set([
  ...imageMimeTypes,
  'application/pdf',
]);

const videoMimeTypes = new Set([
  'video/mp4',
  'video/quicktime',
]);

const uploadDirectories = {
  profile_image: 'profiles',
  kyc_front: 'kyc/front',
  kyc_back: 'kyc/back',
  kyc_portrait: 'kyc/portrait',
  kyc_liveness_video: 'kyc/liveness',
  property_image: 'properties/images',
  property_document: 'properties/documents',
  transaction_document: 'transactions/documents',
  misc: 'misc',
};

const categoryVisibility = {
  profile_image: 'authenticated',
  kyc_front: 'private',
  kyc_back: 'private',
  kyc_portrait: 'private',
  kyc_liveness_video: 'private',
  property_image: 'public_listing',
  property_document: 'private',
  transaction_document: 'private',
  misc: 'authenticated',
};

const acceptedMimeTypesByCategory = {
  profile_image: imageMimeTypes,
  kyc_front: imageMimeTypes,
  kyc_back: imageMimeTypes,
  kyc_portrait: imageMimeTypes,
  kyc_liveness_video: videoMimeTypes,
  property_image: imageMimeTypes,
  property_document: documentMimeTypes,
  transaction_document: documentMimeTypes,
  misc: documentMimeTypes,
};

let s3Client;

function getS3Client() {
  if (config.storageDriver !== 's3') {
    return null;
  }
  if (!s3Client) {
    s3Client = new S3Client({
      region: config.s3Region,
      endpoint: config.s3Endpoint || undefined,
      forcePathStyle: config.s3ForcePathStyle,
      credentials: config.s3AccessKeyId && config.s3SecretAccessKey
        ? {
            accessKeyId: config.s3AccessKeyId,
            secretAccessKey: config.s3SecretAccessKey,
          }
        : undefined,
    });
  }
  return s3Client;
}

function sanitizeFileName(fileName) {
  const raw = String(fileName || 'upload')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9.\-_]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  return raw || 'upload';
}

function extractBase64Payload(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    throw badRequest('base64_data is required.');
  }
  const marker = ';base64,';
  const markerIndex = raw.indexOf(marker);
  return markerIndex >= 0 ? raw.slice(markerIndex + marker.length) : raw;
}

function normalizeMimeType(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

function assetVisibilityForCategory(category) {
  return categoryVisibility[category] ?? 'authenticated';
}

function resolveUploadDirectory(category) {
  return uploadDirectories[category] ?? uploadDirectories.misc;
}

function acceptedMimeTypesForCategory(category) {
  return Array.from(
    acceptedMimeTypesByCategory[category] ?? acceptedMimeTypesByCategory.misc,
  );
}

function listAcceptedMimeTypes(categories = Object.keys(acceptedMimeTypesByCategory)) {
  const accepted = new Set();
  for (const category of categories) {
    for (const mimeType of acceptedMimeTypesForCategory(category)) {
      accepted.add(mimeType);
    }
  }
  return Array.from(accepted);
}

function buildUploadCapabilities(categories = Object.keys(acceptedMimeTypesByCategory)) {
  const normalizedCategories = categories.filter(Boolean);
  return {
    storage_driver: config.storageDriver,
    storage_label: config.storageDriver === 's3' ? 'Cloud upload' : 'Secure upload',
    cloud_enabled: config.storageDriver === 's3',
    max_upload_bytes: config.uploadMaxBytes,
    accepted_mime_types: listAcceptedMimeTypes(normalizedCategories),
    categories: normalizedCategories.map((category) => ({
      key: category,
      accepted_mime_types: acceptedMimeTypesForCategory(category),
      visibility: assetVisibilityForCategory(category),
      cloud_backed: config.storageDriver === 's3',
    })),
  };
}

function resolveRequestBaseUrl(req) {
  const forwardedProto = String(req.headers['x-forwarded-proto'] || '').split(',')[0].trim();
  const protocol = forwardedProto || req.protocol || 'http';
  const forwardedHost = String(req.headers['x-forwarded-host'] || '').split(',')[0].trim();
  const host = forwardedHost || req.get('host') || 'localhost:8080';
  return `${protocol}://${host}`;
}

function signAssetAccess(assetUuid, expiresAt) {
  const payload = `${assetUuid}:${expiresAt}`;
  const signature = crypto
    .createHmac('sha256', config.storageSigningKey || config.jwtSecret)
    .update(payload)
    .digest('base64url');
  return signature;
}

function verifyAssetSignature(assetUuid, expiresAt, signature) {
  const expected = signAssetAccess(assetUuid, expiresAt);
  const expectedBuffer = Buffer.from(expected);
  const providedBuffer = Buffer.from(String(signature || ''));
  if (expectedBuffer.length !== providedBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(expectedBuffer, providedBuffer);
}

function buildSignedAssetUrl(assetUuid, req, expiresAt = Date.now() + config.storageSignedUrlTtlSec * 1000) {
  const expires = String(expiresAt);
  const signature = signAssetAccess(assetUuid, expires);
  const base = config.storageCdnBaseUrl || config.appBaseUrl || resolveRequestBaseUrl(req);
  return `${base.replace(/\/$/, '')}/v1/assets/${assetUuid}/content?expires=${encodeURIComponent(expires)}&signature=${encodeURIComponent(signature)}`;
}

function buildAssetReference(assetUuid) {
  return `asset://${assetUuid}`;
}

function parseAssetReference(value) {
  const raw = String(value || '').trim();
  return raw.startsWith('asset://') ? raw.slice('asset://'.length) : null;
}

async function validateUploadBuffer({
  bytes,
  declaredMimeType,
  fileName,
  category,
}) {
  const detected = await fileTypeFromBuffer(bytes).catch(() => null);
  const detectedMimeType = normalizeMimeType(detected?.mime);
  const declared = normalizeMimeType(declaredMimeType);
  const effectiveMimeType = detectedMimeType || declared;
  const allowedMimeTypes = new Set(acceptedMimeTypesForCategory(category));

  if (!effectiveMimeType || !allowedMimeTypes.has(effectiveMimeType)) {
    throw badRequest('Unsupported file type.');
  }

  if (declared && declared !== effectiveMimeType && !(declared === 'image/jpg' && effectiveMimeType === 'image/jpeg')) {
    throw badRequest('The uploaded file content does not match the declared MIME type.');
  }

  const extension = path.extname(String(fileName || '').trim()).toLowerCase() ||
    `.${mime.extension(effectiveMimeType) || 'bin'}`;

  return {
    detectedMimeType: detectedMimeType || null,
    effectiveMimeType,
    extension,
  };
}

async function persistWithFilesystem(objectKey, bytes) {
  const absolutePath = path.join(config.storagePath, objectKey);
  await fsPromises.mkdir(path.dirname(absolutePath), { recursive: true });
  await fsPromises.writeFile(absolutePath, bytes);
  return {
    bucketName: null,
    objectKey,
    storagePath: objectKey.replace(/\\/g, '/'),
  };
}

async function persistWithS3(objectKey, bytes, mimeType) {
  const client = getS3Client();
  await client.send(
    new PutObjectCommand({
      Bucket: config.s3Bucket,
      Key: objectKey,
      Body: bytes,
      ContentType: mimeType,
    }),
  );
  return {
    bucketName: config.s3Bucket,
    objectKey,
    storagePath: objectKey,
  };
}

async function persistObject({ objectKey, bytes, mimeType }) {
  if (config.storageDriver === 's3') {
    return persistWithS3(objectKey, bytes, mimeType);
  }
  return persistWithFilesystem(objectKey, bytes);
}

async function storeUploadedAsset({
  ownerUserId,
  category,
  fileName,
  mimeType,
  base64Data,
  req,
  expectedChecksum = null,
}) {
  const normalizedCategory = String(category || 'misc').trim().toLowerCase();
  const payload = extractBase64Payload(base64Data);
  const bytes = Buffer.from(payload, 'base64');

  if (!bytes.length) {
    throw badRequest('Uploaded file is empty.');
  }
  if (bytes.length > config.uploadMaxBytes) {
    throw badRequest(`Uploaded file exceeds the ${config.uploadMaxBytes} byte limit.`);
  }

  const fileHash = crypto.createHash('sha256').update(bytes).digest('hex');
  if (expectedChecksum && String(expectedChecksum).toLowerCase() !== fileHash) {
    throw badRequest('Uploaded file checksum mismatch.');
  }

  const validation = await validateUploadBuffer({
    bytes,
    declaredMimeType: mimeType,
    fileName,
    category: normalizedCategory,
  });
  const scan = await scanBufferForMalware(bytes);
  if (scan.status === 'rejected') {
    throw forbidden('The uploaded file was rejected by the security scanner.');
  }

  const folder = resolveUploadDirectory(normalizedCategory);
  const timestamp = new Date();
  const safeFileName = sanitizeFileName(fileName);
  const objectKey = path
    .join(
      folder,
      String(timestamp.getUTCFullYear()),
      String(timestamp.getUTCMonth() + 1).padStart(2, '0'),
      `${Date.now()}-${crypto.randomUUID()}${validation.extension}`,
    )
    .replace(/\\/g, '/');

  const persisted = await persistObject({
    objectKey,
    bytes,
    mimeType: validation.effectiveMimeType,
  });

  const inserted = await query(
    `INSERT INTO uploaded_assets (
        owner_user_id, category, visibility, storage_driver, bucket_name, object_key, storage_path,
        mime_type, detected_mime_type, original_file_name, file_ext, file_size, file_hash,
        malware_scan_status, malware_scan_notes, metadata
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
     RETURNING id, uuid, category, visibility, mime_type, file_size, file_hash, storage_path, created_at`,
    [
      ownerUserId ?? null,
      normalizedCategory,
      assetVisibilityForCategory(normalizedCategory),
      config.storageDriver,
      persisted.bucketName,
      persisted.objectKey,
      persisted.storagePath,
      validation.effectiveMimeType,
      validation.detectedMimeType,
      safeFileName,
      validation.extension,
      bytes.length,
      fileHash,
      scan.status,
      scan.notes,
      JSON.stringify({
        original_name: fileName,
      }),
    ],
  );

  const asset = inserted.rows[0];
  return {
    id: asset.uuid,
    category: asset.category,
    cloud_enabled: config.storageDriver === 's3',
    file_name: safeFileName,
    mime_type: asset.mime_type,
    file_size: asset.file_size,
    file_hash: asset.file_hash,
    storage_driver: config.storageDriver,
    storage_path: buildAssetReference(asset.uuid),
    public_url: buildSignedAssetUrl(asset.uuid, req),
    uploaded_at: asset.created_at,
  };
}

async function getAssetRecord(assetUuid) {
  const result = await query(
    `SELECT *
     FROM uploaded_assets
     WHERE uuid = $1
     LIMIT 1`,
    [assetUuid],
  );
  return result.rows[0] ?? null;
}

async function createAssetAccessUrl(assetUuid, req) {
  const asset = await getAssetRecord(assetUuid);
  if (!asset) {
    throw notFound('Asset not found.');
  }
  if (config.storageDriver === 's3') {
    const client = getS3Client();
    const url = await getSignedUrl(
      client,
      new GetObjectCommand({
        Bucket: asset.bucket_name || config.s3Bucket,
        Key: asset.object_key,
      }),
      { expiresIn: config.storageSignedUrlTtlSec },
    );
    return {
      asset,
      url,
    };
  }
  return {
    asset,
    url: buildSignedAssetUrl(asset.uuid, req),
  };
}

function resolveFilesystemPath(asset) {
  return path.join(config.storagePath, asset.object_key);
}

async function streamAssetToResponse(asset, res) {
  if (config.storageDriver === 's3') {
    const client = getS3Client();
    const url = await getSignedUrl(
      client,
      new GetObjectCommand({
        Bucket: asset.bucket_name || config.s3Bucket,
        Key: asset.object_key,
      }),
      { expiresIn: Math.min(config.storageSignedUrlTtlSec, 300) },
    );
    res.redirect(url);
    return;
  }

  const absolutePath = resolveFilesystemPath(asset);
  await fsPromises.access(absolutePath);
  res.setHeader('content-type', asset.mime_type);
  res.setHeader('cache-control', 'private, max-age=60');
  res.setHeader('x-content-type-options', 'nosniff');
  fs.createReadStream(absolutePath).pipe(res);
}

async function resolveAssetUrlFromReference(value, req) {
  const assetUuid = parseAssetReference(value);
  if (!assetUuid) {
    return String(value || '');
  }
  const { url } = await createAssetAccessUrl(assetUuid, req);
  return url;
}

module.exports = {
  acceptedMimeTypesForCategory,
  buildAssetReference,
  buildUploadCapabilities,
  buildSignedAssetUrl,
  createAssetAccessUrl,
  getAssetRecord,
  parseAssetReference,
  resolveAssetUrlFromReference,
  resolveRequestBaseUrl,
  storeUploadedAsset,
  streamAssetToResponse,
  verifyAssetSignature,
};

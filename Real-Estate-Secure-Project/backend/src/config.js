const crypto = require('crypto');
const path = require('path');

require('dotenv').config({
  path: path.resolve(__dirname, '..', '.env'),
});

function readEnv(name, fallback = undefined) {
  const value = process.env[name];
  if (value === undefined || value === null || String(value).trim() === '') {
    return fallback;
  }
  return String(value).trim();
}

function parseNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function parseCsv(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function isPlaceholderSecret(value, placeholders = []) {
  const normalized = String(value || '').trim().toLowerCase();
  return !normalized || placeholders.map((item) => item.toLowerCase()).includes(normalized);
}

function resolveStoragePath(configuredStoragePath) {
  return path.isAbsolute(configuredStoragePath)
    ? configuredStoragePath
    : path.resolve(__dirname, '..', configuredStoragePath);
}

const environment = readEnv('APP_ENV', readEnv('ENVIRONMENT', 'development'));
const configuredStoragePath = readEnv('STORAGE_PATH', 'storage');

const config = {
  env: environment,
  isProduction: environment === 'production',
  port: parseNumber(readEnv('PORT', '8080'), 8080),
  databaseUrl: readEnv(
    'DATABASE_URL',
    'postgres://postgres:postgres@localhost:5432/real_estate_secure',
  ),
  databaseReadUrl: readEnv('DATABASE_READ_URL', ''),
  autoRunMigrations: parseBoolean(
    readEnv('AUTO_RUN_MIGRATIONS', environment === 'development' ? 'true' : 'false'),
    environment === 'development',
  ),
  autoRunSeeds: parseBoolean(readEnv('AUTO_RUN_SEEDS', 'false'), false),
  corsOrigin: readEnv('CORS_ORIGIN', ''),
  corsOrigins: parseCsv(readEnv('CORS_ORIGIN', '')),
  jwtSecret: readEnv('JWT_SECRET', environment === 'development' ? 'real-estate-secure-dev-secret' : ''),
  jwtRefreshSecret: readEnv(
    'JWT_REFRESH_SECRET',
    environment === 'development' ? 'real-estate-secure-dev-refresh-secret' : '',
  ),
  jwtIssuer: readEnv('JWT_ISSUER', 'real-estate-secure'),
  jwtAudience: readEnv('JWT_AUDIENCE', 'real-estate-secure-clients'),
  accessTokenTtl: readEnv('ACCESS_TOKEN_TTL', '15m'),
  refreshTokenTtl: readEnv('REFRESH_TOKEN_TTL', '30d'),
  refreshSessionMaxDays: parseNumber(readEnv('REFRESH_SESSION_MAX_DAYS', '30'), 30),
  emailVerificationTokenTtlMinutes: parseNumber(
    readEnv('EMAIL_VERIFICATION_TOKEN_TTL_MINUTES', '60'),
    60,
  ),
  passwordResetTokenTtlMinutes: parseNumber(
    readEnv('PASSWORD_RESET_TOKEN_TTL_MINUTES', '30'),
    30,
  ),
  phoneVerificationCodeTtlMinutes: parseNumber(
    readEnv('PHONE_VERIFICATION_CODE_TTL_MINUTES', '10'),
    10,
  ),
  authMaxFailedAttempts: parseNumber(readEnv('AUTH_MAX_FAILED_ATTEMPTS', '5'), 5),
  authLockoutMinutes: parseNumber(readEnv('AUTH_LOCKOUT_MINUTES', '15'), 15),
  authLoginRateLimitWindowMs: parseNumber(
    readEnv('AUTH_LOGIN_RATE_LIMIT_WINDOW_MS', '900000'),
    900000,
  ),
  authLoginRateLimitMax: parseNumber(readEnv('AUTH_LOGIN_RATE_LIMIT_MAX', '10'), 10),
  authPasswordResetRateLimitWindowMs: parseNumber(
    readEnv('AUTH_PASSWORD_RESET_RATE_LIMIT_WINDOW_MS', '3600000'),
    3600000,
  ),
  authPasswordResetRateLimitMax: parseNumber(
    readEnv('AUTH_PASSWORD_RESET_RATE_LIMIT_MAX', '5'),
    5,
  ),
  authRefreshRateLimitWindowMs: parseNumber(
    readEnv('AUTH_REFRESH_RATE_LIMIT_WINDOW_MS', '300000'),
    300000,
  ),
  authRefreshRateLimitMax: parseNumber(readEnv('AUTH_REFRESH_RATE_LIMIT_MAX', '20'), 20),
  mfaTotpIssuer: readEnv('MFA_TOTP_ISSUER', 'Real Estate Secure'),
  mfaTotpDigits: parseNumber(readEnv('MFA_TOTP_DIGITS', '6'), 6),
  mfaTotpStepSec: parseNumber(readEnv('MFA_TOTP_STEP_SEC', '30'), 30),
  mfaTotpWindow: parseNumber(readEnv('MFA_TOTP_WINDOW', '1'), 1),
  exposeActionTokenPreview: parseBoolean(
    readEnv('EXPOSE_ACTION_TOKEN_PREVIEW', 'false'),
    false,
  ),
  bcryptRounds: parseNumber(readEnv('BCRYPT_ROUNDS', '12'), 12),
  jsonLimit: readEnv('JSON_BODY_LIMIT', '16mb'),
  rateLimitWindowMs: parseNumber(
    readEnv(
      'RATE_LIMIT_WINDOW_MS',
      String(parseNumber(readEnv('RATE_LIMIT_WINDOW_SEC', '60'), 60) * 1000),
    ),
    60000,
  ),
  rateLimitMax: parseNumber(readEnv('RATE_LIMIT_MAX', '180'), 180),
  trustProxyHops: parseNumber(readEnv('TRUST_PROXY_HOPS', '0'), 0),
  defaultCountryCode: readEnv('DEFAULT_PHONE_COUNTRY_CODE', '+237'),
  defaultLanguage: readEnv('DEFAULT_LANGUAGE', 'en'),
  notificationsFromEmail: readEnv(
    'NOTIFICATIONS_FROM_EMAIL',
    readEnv('NOTIFICATION_FROM_EMAIL', 'noreply@realestatesecure.cm'),
  ),
  smsSenderId: readEnv('SMS_SENDER_ID', 'RESecure'),
  pushDefaultTitle: readEnv('PUSH_DEFAULT_TITLE', 'Real Estate Secure'),
  storageDriver: readEnv('STORAGE_DRIVER', 'filesystem'),
  storagePath: resolveStoragePath(configuredStoragePath),
  storageBaseUrl: readEnv('STORAGE_BASE_URL', ''),
  storageCdnBaseUrl: readEnv('STORAGE_CDN_BASE_URL', ''),
  storageSignedUrls: parseBoolean(readEnv('STORAGE_REQUIRE_SIGNED_URLS'), true),
  storageEncryptionKey: readEnv('STORAGE_ENCRYPTION_KEY', ''),
  storageSigningKey: readEnv('STORAGE_SIGNING_KEY', ''),
  storageSignedUrlTtlSec: parseNumber(readEnv('STORAGE_SIGNED_URL_TTL_SEC', '900'), 900),
  s3Endpoint: readEnv('OBJECT_STORAGE_ENDPOINT', ''),
  s3Region: readEnv('OBJECT_STORAGE_REGION', 'africa-central'),
  s3Bucket: readEnv('OBJECT_STORAGE_BUCKET', 'real-estate-secure-assets'),
  s3AccessKeyId: readEnv('OBJECT_STORAGE_ACCESS_KEY_ID', ''),
  s3SecretAccessKey: readEnv('OBJECT_STORAGE_SECRET_ACCESS_KEY', ''),
  s3ForcePathStyle: parseBoolean(readEnv('OBJECT_STORAGE_FORCE_PATH_STYLE', 'true'), true),
  uploadMaxBytes: parseNumber(readEnv('UPLOAD_MAX_BYTES', String(12 * 1024 * 1024)), 12 * 1024 * 1024),
  appBaseUrl: readEnv('APP_BASE_URL', 'http://localhost:8080'),
  mobileAppDeepLinkBaseUrl: readEnv('MOBILE_APP_DEEP_LINK_BASE_URL', 'realestatesecure://auth'),
  kycCaptureFallbackPolicy: readEnv(
    'KYC_CAPTURE_FALLBACK_POLICY',
    'no_fallback',
  ),
  sumsubApiBaseUrl: readEnv('SUMSUB_API_BASE_URL', 'https://api.sumsub.com'),
  sumsubAppToken: readEnv('SUMSUB_APP_TOKEN', ''),
  sumsubSecretKey: readEnv('SUMSUB_SECRET_KEY', ''),
  sumsubWebhookSecret: readEnv('SUMSUB_WEBHOOK_SECRET', ''),
  sumsubLevelName: readEnv('SUMSUB_LEVEL_NAME', 'real-estate-secure-basic'),
  sumsubLevelNameBuyer: readEnv('SUMSUB_LEVEL_NAME_BUYER', ''),
  sumsubLevelNameSeller: readEnv('SUMSUB_LEVEL_NAME_SELLER', ''),
  sumsubLevelNameLawyer: readEnv('SUMSUB_LEVEL_NAME_LAWYER', ''),
  sumsubLevelNameNotary: readEnv('SUMSUB_LEVEL_NAME_NOTARY', ''),
  sumsubContactActionLevelName: readEnv(
    'SUMSUB_CONTACT_ACTION_LEVEL_NAME',
    readEnv(
      'SUMSUB_EMAIL_ACTION_LEVEL_NAME',
      readEnv(
        'SUMSUB_PHONE_ACTION_LEVEL_NAME',
        'real-estate-secure-contact-verification',
      ),
    ),
  ),
  sumsubAccessTokenTtlSec: parseNumber(readEnv('SUMSUB_ACCESS_TOKEN_TTL_SEC', '600'), 600),
  paymentGatewayProvider: readEnv('PAYMENT_GATEWAY_PROVIDER', 'notchpay'),
  notchPayBaseUrl: readEnv('NOTCHPAY_BASE_URL', 'https://api.notchpay.co'),
  notchPayPublicKey: readEnv('NOTCHPAY_PUBLIC_KEY', ''),
  notchPayPrivateKey: readEnv('NOTCHPAY_PRIVATE_KEY', ''),
  notchPayCallbackUrl: readEnv(
    'NOTCHPAY_CALLBACK_URL',
    `${readEnv('APP_BASE_URL', 'http://localhost:8080')}/payments/notchpay/return`,
  ),
  notchPayWebhookSecret: readEnv('NOTCHPAY_WEBHOOK_SECRET', ''),
  redisUrl: readEnv('REDIS_URL', ''),
  dashboardCacheTtlSec: parseNumber(readEnv('DASHBOARD_CACHE_TTL_SEC', '60'), 60),
  jobPollIntervalMs: parseNumber(readEnv('JOB_POLL_INTERVAL_MS', '5000'), 5000),
  queuePrefix: readEnv('QUEUE_PREFIX', 'real-estate-secure'),
  fieldEncryptionKey: readEnv('FIELD_ENCRYPTION_KEY', ''),
  malwareScanMode: readEnv('MALWARE_SCAN_MODE', 'heuristic'),
  malwareScanHost: readEnv('MALWARE_SCAN_HOST', '127.0.0.1'),
  malwareScanPort: parseNumber(readEnv('MALWARE_SCAN_PORT', '3310'), 3310),
  malwareScanTimeoutMs: parseNumber(readEnv('MALWARE_SCAN_TIMEOUT_MS', '5000'), 5000),
  malwareScanFailClosed: parseBoolean(readEnv('MALWARE_SCAN_FAIL_CLOSED', 'false'), false),
  malwareScanRejectInfected: parseBoolean(readEnv('MALWARE_SCAN_REJECT_INFECTED', 'true'), true),
  auditPrivilegedReads: parseBoolean(readEnv('AUDIT_PRIVILEGED_READS', 'true'), true),
};

function assertProductionConfig(currentConfig) {
  if (!currentConfig.isProduction) {
    return;
  }

  const errors = [];

  if (currentConfig.corsOrigins.length === 0) {
    errors.push('CORS_ORIGIN must list explicit origins in production.');
  }
  if (currentConfig.corsOrigins.includes('*')) {
    errors.push('CORS_ORIGIN cannot use * in production.');
  }
  if (
    isPlaceholderSecret(currentConfig.jwtSecret, [
      'real-estate-secure-dev-secret',
      'change-me',
      'secret',
    ]) ||
    currentConfig.jwtSecret.length < 32
  ) {
    errors.push('JWT_SECRET must be set to a strong production secret.');
  }
  if (
    isPlaceholderSecret(currentConfig.jwtRefreshSecret, [
      'real-estate-secure-dev-refresh-secret',
      'change-me-refresh',
      'secret',
    ]) ||
    currentConfig.jwtRefreshSecret.length < 32
  ) {
    errors.push('JWT_REFRESH_SECRET must be set to a strong production secret.');
  }
  if (isPlaceholderSecret(currentConfig.storageSigningKey, ['change-me'])) {
    errors.push('STORAGE_SIGNING_KEY must be set in production.');
  }
  if (currentConfig.storageDriver === 'filesystem') {
    errors.push('STORAGE_DRIVER=filesystem is not allowed in production.');
  }
  if (!currentConfig.storageSignedUrls) {
    errors.push('STORAGE_REQUIRE_SIGNED_URLS must be true in production.');
  }
  if (currentConfig.storageDriver === 's3') {
    if (!currentConfig.s3Endpoint || !currentConfig.s3AccessKeyId || !currentConfig.s3SecretAccessKey) {
      errors.push('Object storage endpoint and credentials are required for STORAGE_DRIVER=s3.');
    }
  }
  if (!currentConfig.redisUrl) {
    errors.push('REDIS_URL is required in production.');
  }
  if (!currentConfig.fieldEncryptionKey || currentConfig.fieldEncryptionKey.length < 32) {
    errors.push('FIELD_ENCRYPTION_KEY must be set to a strong value in production.');
  }

  if (errors.length > 0) {
    throw new Error(
      `Production configuration is invalid:\n- ${errors.join('\n- ')}`,
    );
  }
}

function stableHash(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest('hex');
}

assertProductionConfig(config);

module.exports = {
  config,
  parseBoolean,
  parseCsv,
  parseNumber,
  readEnv,
  stableHash,
};

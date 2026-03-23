const crypto = require('crypto');

const { config, stableHash } = require('../config');

const ENCRYPTION_PREFIX = 'enc:v1';

function deriveKey() {
  const seed = config.fieldEncryptionKey || config.storageEncryptionKey || config.jwtSecret;
  return crypto.createHash('sha256').update(String(seed || '')).digest();
}

function encryptValue(value) {
  if (value === undefined || value === null || String(value) === '') {
    return null;
  }

  const normalized = String(value);
  if (normalized.startsWith(`${ENCRYPTION_PREFIX}:`)) {
    return normalized;
  }

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', deriveKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(normalized, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return `${ENCRYPTION_PREFIX}:${iv.toString('base64url')}:${authTag.toString('base64url')}:${ciphertext.toString('base64url')}`;
}

function decryptValue(value) {
  const normalized = String(value || '');
  if (!normalized.startsWith(`${ENCRYPTION_PREFIX}:`)) {
    return normalized;
  }

  const [, version, encodedIv, encodedTag, encodedCiphertext] = normalized.split(':');
  if (version !== 'v1' || !encodedIv || !encodedTag || !encodedCiphertext) {
    return normalized;
  }

  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    deriveKey(),
    Buffer.from(encodedIv, 'base64url'),
  );
  decipher.setAuthTag(Buffer.from(encodedTag, 'base64url'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(encodedCiphertext, 'base64url')),
    decipher.final(),
  ]);
  return plaintext.toString('utf8');
}

function decryptValueSafely(value) {
  try {
    return decryptValue(value);
  } catch (error) {
    return String(value || '');
  }
}

function tokenHash(value) {
  return stableHash(value);
}

module.exports = {
  decryptValue,
  decryptValueSafely,
  encryptValue,
  tokenHash,
};

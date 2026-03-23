const crypto = require('crypto');

const { config } = require('../config');
const { badRequest } = require('../lib/errors');
const { decryptValueSafely, encryptValue } = require('./field-crypto');

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function encodeBase32(buffer) {
  let bits = 0;
  let value = 0;
  let output = '';

  for (const byte of buffer) {
    value = (value << 8) | byte;
    bits += 8;

    while (bits >= 5) {
      output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }

  if (bits > 0) {
    output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  }

  return output;
}

function decodeBase32(secret) {
  const normalized = String(secret || '')
    .toUpperCase()
    .replace(/=+$/g, '')
    .replace(/[^A-Z2-7]/g, '');

  if (!normalized) {
    throw badRequest('A valid TOTP secret is required.');
  }

  let bits = 0;
  let value = 0;
  const bytes = [];

  for (const char of normalized) {
    const index = BASE32_ALPHABET.indexOf(char);
    if (index < 0) {
      continue;
    }
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }

  return Buffer.from(bytes);
}

function generateTotpSecret(length = 20) {
  return encodeBase32(crypto.randomBytes(length));
}

function normalizeTotpCode(code) {
  return String(code || '').replace(/\s+/g, '').trim();
}

function buildCounterBuffer(counter) {
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(BigInt(counter));
  return buffer;
}

function generateTotpCode(secret, timestamp = Date.now()) {
  const digits = Math.max(6, Number(config.mfaTotpDigits || 6));
  const stepSec = Math.max(15, Number(config.mfaTotpStepSec || 30));
  const counter = Math.floor(timestamp / 1000 / stepSec);
  const secretBytes = decodeBase32(secret);
  const digest = crypto
    .createHmac('sha1', secretBytes)
    .update(buildCounterBuffer(counter))
    .digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const binary =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);

  return String(binary % (10 ** digits)).padStart(digits, '0');
}

function verifyTotpCode(secret, code) {
  const normalizedCode = normalizeTotpCode(code);
  if (!/^\d+$/.test(normalizedCode)) {
    return false;
  }

  const window = Math.max(0, Number(config.mfaTotpWindow || 1));
  const stepMs = Math.max(15, Number(config.mfaTotpStepSec || 30)) * 1000;
  const now = Date.now();

  for (let index = -window; index <= window; index += 1) {
    if (generateTotpCode(secret, now + index * stepMs) === normalizedCode) {
      return true;
    }
  }

  return false;
}

function buildOtpAuthUrl({ issuer = config.mfaTotpIssuer, accountName, secret }) {
  const encodedIssuer = encodeURIComponent(String(issuer || 'Real Estate Secure'));
  const encodedAccount = encodeURIComponent(String(accountName || 'user'));
  return `otpauth://totp/${encodedIssuer}:${encodedAccount}?secret=${encodeURIComponent(secret)}&issuer=${encodedIssuer}&algorithm=SHA1&digits=${encodeURIComponent(String(config.mfaTotpDigits || 6))}&period=${encodeURIComponent(String(config.mfaTotpStepSec || 30))}`;
}

function encryptTotpSecret(secret) {
  return encryptValue(secret);
}

function decryptTotpSecret(secret) {
  return decryptValueSafely(secret);
}

module.exports = {
  buildOtpAuthUrl,
  decryptTotpSecret,
  encryptTotpSecret,
  generateTotpCode,
  generateTotpSecret,
  normalizeTotpCode,
  verifyTotpCode,
};

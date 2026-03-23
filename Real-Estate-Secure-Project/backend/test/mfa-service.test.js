const { describe, test } = require('node:test');
const assert = require('node:assert/strict');

const {
  buildOtpAuthUrl,
  decryptTotpSecret,
  encryptTotpSecret,
  generateTotpCode,
  generateTotpSecret,
  verifyTotpCode,
} = require('../src/services/mfa-service');

describe('mfa-service', () => {
  test('generates secrets and verifies current TOTP codes', () => {
    const secret = generateTotpSecret();
    const code = generateTotpCode(secret);

    assert.ok(secret.length >= 16);
    assert.equal(verifyTotpCode(secret, code), true);
    assert.equal(verifyTotpCode(secret, '000000'), false);
  });

  test('builds OTPAuth URIs for authenticator apps', () => {
    const secret = generateTotpSecret();
    const url = buildOtpAuthUrl({
      issuer: 'Real Estate Secure',
      accountName: 'buyer@example.com',
      secret,
    });

    assert.match(url, /^otpauth:\/\/totp\//);
    assert.match(url, /buyer%40example.com/);
    assert.match(url, new RegExp(`secret=${secret}`));
  });

  test('encrypts and decrypts stored TOTP secrets safely', () => {
    const secret = generateTotpSecret();
    const encrypted = encryptTotpSecret(secret);

    assert.notEqual(encrypted, secret);
    assert.equal(decryptTotpSecret(encrypted), secret);
  });
});
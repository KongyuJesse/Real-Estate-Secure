const { after, describe, test } = require('node:test');
const assert = require('node:assert/strict');

const { closePools } = require('../src/db');
const {
  assertCoordinatesWithinCameroon,
  normalizeCameroonPhoneNumber,
} = require('../src/services/cameroon-validation-service');

after(async () => {
  await closePools();
});

describe('cameroon-validation-service', () => {
  test('normalizes Cameroon phone numbers into E.164 format', () => {
    assert.equal(normalizeCameroonPhoneNumber('677 123 456'), '+237677123456');
    assert.equal(normalizeCameroonPhoneNumber('+237 233 445 566'), '+237233445566');
  });

  test('rejects invalid Cameroon numbering plans', () => {
    assert.throws(
      () => normalizeCameroonPhoneNumber('577123456'),
      /Cameroon numbering range/,
    );
    assert.throws(
      () => normalizeCameroonPhoneNumber('67712345'),
      /valid 9-digit Cameroon local number/,
    );
  });

  test('accepts coordinates inside Cameroon bounds', () => {
    assert.deepEqual(assertCoordinatesWithinCameroon(4.0511, 9.7679), {
      latitude: 4.0511,
      longitude: 9.7679,
    });
  });

  test('rejects coordinates outside Cameroon bounds', () => {
    assert.throws(
      () => assertCoordinatesWithinCameroon(20, 9.7),
      /must fall within Cameroon/,
    );
  });
});
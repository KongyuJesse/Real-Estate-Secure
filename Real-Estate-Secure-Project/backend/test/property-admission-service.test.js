const { describe, test } = require('node:test');
const assert = require('node:assert/strict');

const { evaluatePropertyAdmission } = require('../src/services/property-admission-service');

describe('property-admission-service', () => {
  test('marks non-sale listings as immediately eligible', () => {
    const result = evaluatePropertyAdmission({
      listingType: 'rent',
      sellerIdentityVerifiedSnapshot: false,
    });

    assert.equal(result.riskLane, 'government_light');
    assert.equal(result.admissionStatus, 'eligible');
    assert.equal(result.marketplaceEligible, true);
  });

  test('keeps sale listings under review when seller verification or required evidence is missing', () => {
    const result = evaluatePropertyAdmission({
      listingType: 'sale',
      inventoryType: 'titled_private',
      sellerIdentityVerifiedSnapshot: false,
      documentTypes: ['certificate_of_property'],
    });

    assert.equal(result.riskLane, 'government_light');
    assert.equal(result.admissionStatus, 'under_review');
    assert.equal(result.marketplaceEligible, false);
    assert.deepEqual(result.missingDocuments, [
      'urbanism_certificate',
      'accessibility_certificate',
    ]);
  });

  test('approves low-risk sale listings once seller and evidence checks pass', () => {
    const result = evaluatePropertyAdmission({
      listingType: 'sale',
      inventoryType: 'titled_private',
      sellerIdentityVerifiedSnapshot: true,
      documentTypes: [
        'certificate_of_property',
        'urbanism_certificate',
        'accessibility_certificate',
      ],
    });

    assert.equal(result.riskLane, 'government_light');
    assert.equal(result.admissionStatus, 'eligible');
    assert.equal(result.marketplaceEligible, true);
    assert.deepEqual(result.missingDocuments, []);
  });

  test('routes riskier sale cases into assisted handling', () => {
    const result = evaluatePropertyAdmission({
      listingType: 'sale',
      inventoryType: 'titled_private',
      sellerIdentityVerifiedSnapshot: true,
      foreignPartyExpected: true,
      documentTypes: [
        'certificate_of_property',
        'urbanism_certificate',
        'accessibility_certificate',
      ],
    });

    assert.equal(result.riskLane, 'assisted_only');
    assert.equal(result.admissionStatus, 'assisted_only');
    assert.equal(result.marketplaceEligible, false);
  });

  test('blocks untitled customary sale inventory', () => {
    const result = evaluatePropertyAdmission({
      listingType: 'sale',
      inventoryType: 'untitled_customary',
      sellerIdentityVerifiedSnapshot: true,
    });

    assert.equal(result.riskLane, 'blocked');
    assert.equal(result.admissionStatus, 'blocked');
    assert.equal(result.marketplaceEligible, false);
  });
});
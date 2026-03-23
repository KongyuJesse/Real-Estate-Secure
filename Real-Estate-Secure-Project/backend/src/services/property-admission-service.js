function normalizeValue(value) {
  return String(value || '').trim().toLowerCase();
}

function evaluatePropertyAdmission({
  listingType,
  inventoryType,
  sellerIdentityVerifiedSnapshot,
  declaredEncumbrance,
  declaredDispute,
  foreignPartyExpected,
  oldTitleRisk,
  courtLinked,
  ministryFilingRequired,
  municipalCertificateRequired,
  documentTypes = [],
}) {
  const normalizedListingType = normalizeValue(listingType);
  const normalizedInventoryType = normalizeValue(inventoryType || 'titled_private');
  const normalizedDocumentTypes = new Set(documentTypes.map(normalizeValue));
  const notes = [];
  const missingDocuments = [];

  if (normalizedListingType !== 'sale') {
    return {
      riskLane: 'government_light',
      admissionStatus: 'eligible',
      marketplaceEligible: true,
      notes: ['Non-sale inventory is eligible for the standard marketplace lane.'],
      missingDocuments,
    };
  }

  if (normalizedInventoryType === 'untitled_customary') {
    return {
      riskLane: 'blocked',
      admissionStatus: 'blocked',
      marketplaceEligible: false,
      notes: ['Untitled customary land is blocked from the standard marketplace sale flow.'],
      missingDocuments,
    };
  }

  if (
    [
      'domain_national',
      'succession_estate',
      'judgment_enforcement',
      'old_title_regularization',
      'other',
    ].includes(normalizedInventoryType)
  ) {
    notes.push('Inventory type requires assisted legal handling outside the government-light sale lane.');
    return {
      riskLane: 'assisted_only',
      admissionStatus: 'assisted_only',
      marketplaceEligible: false,
      notes,
      missingDocuments,
    };
  }

  if (
    foreignPartyExpected ||
    declaredEncumbrance ||
    declaredDispute ||
    oldTitleRisk ||
    courtLinked ||
    ministryFilingRequired
  ) {
    notes.push('Declared legal or operational risk flags require assisted legal handling.');
    return {
      riskLane: 'assisted_only',
      admissionStatus: 'assisted_only',
      marketplaceEligible: false,
      notes,
      missingDocuments,
    };
  }

  const requiredDocuments = [
    'certificate_of_property',
    'urbanism_certificate',
    'accessibility_certificate',
  ];

  if (municipalCertificateRequired) {
    requiredDocuments.push('municipal_certificate');
  }

  for (const documentType of requiredDocuments) {
    if (!normalizedDocumentTypes.has(documentType)) {
      missingDocuments.push(documentType);
    }
  }

  if (!sellerIdentityVerifiedSnapshot) {
    notes.push('Seller identity must be verified before the property can enter the low-risk sale lane.');
  }

  if (missingDocuments.length > 0) {
    notes.push('Required sale admission evidence is missing.');
  }

  if (!sellerIdentityVerifiedSnapshot || missingDocuments.length > 0) {
    return {
      riskLane: 'government_light',
      admissionStatus: 'under_review',
      marketplaceEligible: false,
      notes,
      missingDocuments,
    };
  }

  notes.push('Property satisfies the low-risk government-light sale lane baseline.');
  return {
    riskLane: 'government_light',
    admissionStatus: 'eligible',
    marketplaceEligible: true,
    notes,
    missingDocuments,
  };
}

module.exports = {
  evaluatePropertyAdmission,
};
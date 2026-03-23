const restrictedMobileRoles = new Set([
  'admin',
  'super_admin',
  'moderator',
  'auditor',
]);

const legacyRoleMap = new Map([
  ['tenant', 'buyer'],
  ['landlord', 'seller'],
  ['agent', 'seller'],
  ['super_admin', 'admin'],
]);

const canonicalMobileRoles = new Set([
  'buyer',
  'seller',
  'lawyer',
  'notary',
]);

const mobileRegistrationRoles = new Set([
  'buyer',
  'seller',
  'lawyer',
  'notary',
]);

const mobileSelfServiceRoles = new Set(canonicalMobileRoles);

function normalizeRole(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function canonicalizeRole(role) {
  const normalized = normalizeRole(role);
  return legacyRoleMap.get(normalized) ?? normalized;
}

function canonicalizeRoles(roles = []) {
  const values = [];
  const seen = new Set();

  for (const role of roles) {
    const canonical = canonicalizeRole(role);
    if (!canonical || seen.has(canonical)) {
      continue;
    }
    seen.add(canonical);
    values.push(canonical);
  }

  return values;
}

function resolvePrimaryMobileRole(roles = [], primaryRole = '') {
  const preferred = canonicalizeRole(primaryRole);
  if (preferred && !restrictedMobileRoles.has(normalizeRole(primaryRole))) {
    return preferred;
  }

  return canonicalizeRoles(roles)[0] ?? 'buyer';
}

function hasRestrictedMobileRole(roles = []) {
  return roles.some((role) => restrictedMobileRoles.has(normalizeRole(role)));
}

function isAllowedMobileRegistrationRole(role) {
  return mobileRegistrationRoles.has(canonicalizeRole(role));
}

function isAllowedMobileSelfServiceRole(role) {
  return mobileSelfServiceRoles.has(canonicalizeRole(role));
}

module.exports = {
  canonicalMobileRoles,
  canonicalizeRole,
  canonicalizeRoles,
  restrictedMobileRoles,
  mobileRegistrationRoles,
  mobileSelfServiceRoles,
  normalizeRole,
  resolvePrimaryMobileRole,
  hasRestrictedMobileRole,
  isAllowedMobileRegistrationRole,
  isAllowedMobileSelfServiceRole,
};

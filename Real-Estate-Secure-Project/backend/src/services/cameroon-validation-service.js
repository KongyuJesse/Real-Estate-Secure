const { query } = require('../db');
const { config } = require('../config');
const { badRequest } = require('../lib/errors');

const CAMEROON_COORDINATE_BOUNDS = {
  minLatitude: 1.5,
  maxLatitude: 13.2,
  minLongitude: 8.0,
  maxLongitude: 16.4,
};

function normalizeText(value) {
  return String(value || '').trim();
}

function normalizeLookupValue(value) {
  return normalizeText(value).toLowerCase();
}

function normalizeCameroonPhoneNumber(phoneNumber, defaultCountryCode = config.defaultCountryCode) {
  const raw = String(phoneNumber || '').replace(/[^\d+]/g, '');
  if (!raw) {
    throw badRequest('A valid Cameroon phone number is required.');
  }

  let digits = raw;
  if (digits.startsWith('+')) {
    digits = digits.slice(1);
  }

  const normalizedCountryCode = String(defaultCountryCode || '+237').replace(/[^\d]/g, '') || '237';

  if (digits.startsWith(normalizedCountryCode)) {
    digits = digits.slice(normalizedCountryCode.length);
  }

  if (digits.startsWith('0') && digits.length === 10) {
    digits = digits.slice(1);
  }

  if (!/^\d{9}$/.test(digits)) {
    throw badRequest('Phone numbers must use a valid 9-digit Cameroon local number.');
  }

  if (!/^[26]/.test(digits)) {
    throw badRequest('Phone numbers must use a valid Cameroon numbering range.');
  }

  return `+${normalizedCountryCode}${digits}`;
}

function assertCoordinatesWithinCameroon(latitude, longitude) {
  const lat = Number(latitude);
  const lng = Number(longitude);

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw badRequest('Latitude and longitude must be numeric values.');
  }

  if (
    lat < CAMEROON_COORDINATE_BOUNDS.minLatitude ||
    lat > CAMEROON_COORDINATE_BOUNDS.maxLatitude ||
    lng < CAMEROON_COORDINATE_BOUNDS.minLongitude ||
    lng > CAMEROON_COORDINATE_BOUNDS.maxLongitude
  ) {
    throw badRequest('Coordinates must fall within Cameroon.');
  }

  return {
    latitude: lat,
    longitude: lng,
  };
}

async function listCameroonAdministrativeCatalog() {
  const result = await query(
    `SELECT
        r.code,
        r.name,
        r.capital,
        COALESCE(
          json_agg(
            json_build_object(
              'code', d.code,
              'name', d.name
            )
            ORDER BY d.name
          ) FILTER (WHERE d.code IS NOT NULL),
          '[]'::json
        ) AS departments
     FROM cameroon_regions r
     LEFT JOIN cameroon_departments d ON d.region_code = r.code
     GROUP BY r.code, r.name, r.capital
     ORDER BY r.name ASC`,
  );

  return result.rows.map((row) => ({
    code: String(row.code || '').trim(),
    name: String(row.name || '').trim(),
    capital: String(row.capital || '').trim(),
    departments: Array.isArray(row.departments)
      ? row.departments.map((department) => ({
          code: String(department?.code || '').trim(),
          name: String(department?.name || '').trim(),
        }))
      : [],
  }));
}

async function resolveCameroonRegionDepartment({ region, department }) {
  const normalizedRegion = normalizeLookupValue(region);
  const normalizedDepartment = normalizeLookupValue(department);

  if (!normalizedRegion || !normalizedDepartment) {
    throw badRequest('Region and department are required.');
  }

  const result = await query(
    `SELECT
        r.code AS region_code,
        r.name AS region_name,
        d.code AS department_code,
        d.name AS department_name
     FROM cameroon_regions r
     JOIN cameroon_departments d ON d.region_code = r.code
     WHERE (LOWER(r.name) = $1 OR LOWER(r.code) = $1)
       AND (LOWER(d.name) = $2 OR LOWER(d.code) = $2)
     LIMIT 1`,
    [normalizedRegion, normalizedDepartment],
  );

  if (!result.rows[0]) {
    throw badRequest('Region and department must match a valid Cameroon administrative area.');
  }

  return result.rows[0];
}

async function validateCameroonPropertyLocation({ region, department, latitude, longitude }) {
  const area = await resolveCameroonRegionDepartment({ region, department });
  const coordinates = assertCoordinatesWithinCameroon(latitude, longitude);

  return {
    region: area.region_name,
    regionCode: area.region_code,
    department: area.department_name,
    departmentCode: area.department_code,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
  };
}

module.exports = {
  assertCoordinatesWithinCameroon,
  listCameroonAdministrativeCatalog,
  normalizeCameroonPhoneNumber,
  resolveCameroonRegionDepartment,
  validateCameroonPropertyLocation,
};

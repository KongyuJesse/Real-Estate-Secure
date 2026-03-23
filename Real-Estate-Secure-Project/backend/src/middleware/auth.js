const { verifyAccessToken, assertAccessSessionActive } = require('../services/auth-service');
const { unauthorized, forbidden } = require('../lib/errors');

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(unauthorized());
  }

  try {
    req.auth = verifyAccessToken(token);
    await assertAccessSessionActive(req.auth.sid);
    return next();
  } catch (error) {
    return next(unauthorized('Your session is invalid or has expired.'));
  }
}

function requireRole(...allowedRoles) {
  const expected = new Set(allowedRoles.flat().filter(Boolean));
  return (req, res, next) => {
    if (!req.auth) {
      return next(unauthorized());
    }
    const roles = Array.isArray(req.auth.roles) ? req.auth.roles : [];
    const allowed = roles.some((role) => expected.has(role));
    if (!allowed) {
      return next(forbidden());
    }
    return next();
  };
}

module.exports = { requireAuth, requireRole };

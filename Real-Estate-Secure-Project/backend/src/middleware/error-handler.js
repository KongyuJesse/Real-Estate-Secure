const { AppError } = require('../lib/errors');
const { errorPayload } = require('../lib/http');

function errorHandler(error, req, res, next) { // eslint-disable-line no-unused-vars
  if (!(error instanceof AppError)) {
    console.error(`[${req.requestId}]`, error);
  }

  const normalized = error instanceof AppError
    ? error
    : new AppError('Internal server error.', 500, 'INTERNAL_ERROR');

  return errorPayload(res, normalized);
}

module.exports = { errorHandler };

class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR', details = undefined) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

function badRequest(message, details) {
  return new AppError(message, 400, 'BAD_REQUEST', details);
}

function unauthorized(message = 'Authentication required.') {
  return new AppError(message, 401, 'UNAUTHORIZED');
}

function forbidden(message = 'You do not have permission to perform this action.') {
  return new AppError(message, 403, 'FORBIDDEN');
}

function notFound(message = 'Resource not found.') {
  return new AppError(message, 404, 'NOT_FOUND');
}

function conflict(message) {
  return new AppError(message, 409, 'CONFLICT');
}

function tooManyRequests(message = 'Too many requests. Please try again later.') {
  return new AppError(message, 429, 'TOO_MANY_REQUESTS');
}

module.exports = {
  AppError,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  tooManyRequests,
};

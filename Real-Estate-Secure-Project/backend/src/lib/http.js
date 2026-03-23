function success(res, data, meta = undefined, statusCode = 200) {
  const payload = {
    status: 'success',
    data,
    request_id: res.locals.requestId,
  };
  if (meta !== undefined) {
    payload.meta = meta;
  }
  return res.status(statusCode).json(payload);
}

function errorPayload(res, error) {
  return res.status(error.statusCode || 500).json({
    status: 'error',
    error: {
      message: error.message || 'Request failed.',
      code: error.code || 'INTERNAL_ERROR',
      details: error.details,
    },
    request_id: res.locals.requestId,
  });
}

module.exports = { success, errorPayload };

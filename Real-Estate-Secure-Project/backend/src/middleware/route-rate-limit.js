const rateLimit = require('express-rate-limit');
const { RedisStore } = require('rate-limit-redis');

const { tooManyRequests } = require('../lib/errors');
const { getRedis } = require('../services/redis-service');

function buildStore() {
  const redis = getRedis();
  if (!redis) {
    return undefined;
  }

  return new RedisStore({
    sendCommand: (...args) => redis.call(args[0], ...args.slice(1)),
  });
}

function createRouteRateLimiter({
  windowMs,
  max,
  keyGenerator,
  message,
  skipSuccessfulRequests = false,
}) {
  return rateLimit({
    windowMs,
    max,
    keyGenerator,
    skipSuccessfulRequests,
    standardHeaders: true,
    legacyHeaders: false,
    store: buildStore(),
    handler(req, res, next) {
      next(tooManyRequests(message));
    },
  });
}

module.exports = {
  createRouteRateLimiter,
};
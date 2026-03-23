const compression = require('compression');
const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { RedisStore } = require('rate-limit-redis');

const { config } = require('./config');
const { requestContext } = require('./middleware/request-context');
const { errorHandler } = require('./middleware/error-handler');
const { buildApiRouter } = require('./routes');
const { getRedis } = require('./services/redis-service');

const app = express();

function captureRawBody(req, res, buffer) {
  if (!buffer || buffer.length === 0) {
    return;
  }
  if (
    req.originalUrl
    && (
      req.originalUrl.includes('/webhooks/notchpay')
      || req.originalUrl.includes('/webhooks/kyc')
    )
  ) {
    req.rawBody = buffer.toString('utf8');
  }
}

function buildRateLimitStore() {
  const redis = getRedis();
  if (!redis) {
    return undefined;
  }
  return new RedisStore({
    sendCommand: (...args) => redis.call(args[0], ...args.slice(1)),
  });
}

app.disable('x-powered-by');
app.set('trust proxy', config.trustProxyHops > 0 ? config.trustProxyHops : false);
app.use(requestContext);
app.use(helmet({
  crossOriginResourcePolicy: false,
}));
app.use(
  cors({
    origin(origin, callback) {
      if (!origin) {
        callback(null, true);
        return;
      }
      if (config.corsOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Origin is not allowed by CORS.'));
    },
    credentials: true,
  }),
);
app.use(compression());
app.use(express.json({ limit: config.jsonLimit, verify: captureRawBody }));
app.use(express.urlencoded({ extended: false, limit: config.jsonLimit }));
app.use(
  rateLimit({
    windowMs: config.rateLimitWindowMs,
    max: config.rateLimitMax,
    standardHeaders: true,
    legacyHeaders: false,
    store: buildRateLimitStore(),
  }),
);

app.get('/', (req, res) => {
  res.json({
    status: 'success',
    data: {
      name: 'real-estate-secure-backend',
      version: '1.0.0',
      runtime: 'node-express',
      environment: config.env,
    },
    request_id: req.requestId,
  });
});

const apiRouter = buildApiRouter();
app.use('/v1', apiRouter);
app.use('/', apiRouter);

app.use(errorHandler);

module.exports = { app };

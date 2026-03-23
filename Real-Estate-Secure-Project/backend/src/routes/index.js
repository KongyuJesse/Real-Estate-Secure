const express = require('express');

const { requireAuth, requireRole } = require('../middleware/auth');
const { buildHealthRouter } = require('./health');
const { buildAuthRouter } = require('./auth');
const { buildUsersRouter } = require('./users');
const { buildPropertiesRouter } = require('./properties');
const { buildTransactionsRouter } = require('./transactions');
const { buildNotificationsRouter } = require('./notifications');
const { buildDirectoriesRouter } = require('./directories');
const { buildMessagingRouter } = require('./messaging');
const { buildCommerceRouter } = require('./commerce');
const { buildGovernanceRouter } = require('./governance');
const { buildUploadsRouter } = require('./uploads');
const { buildAssetsRouter } = require('./assets');

function buildApiRouter() {
  const router = express.Router();
  const healthRouter = buildHealthRouter();

  router.use('/health', healthRouter);
  router.get('/ready', healthRouter._readinessHandler);
  router.use('/auth', buildAuthRouter());
  router.use('/users', buildUsersRouter());
  router.use('/properties', buildPropertiesRouter());
  router.use('/uploads', requireAuth, buildUploadsRouter());
  router.use('/assets', buildAssetsRouter({ requireAuth }));
  router.use('/transactions', requireAuth, buildTransactionsRouter());
  router.use('/notifications', requireAuth, buildNotificationsRouter());
  router.use('/', buildDirectoriesRouter());
  router.use('/', requireAuth, buildMessagingRouter());
  router.use('/', buildCommerceRouter());
  router.use('/', buildGovernanceRouter({ requireAuth, requireRole }));

  return router;
}

module.exports = { buildApiRouter };

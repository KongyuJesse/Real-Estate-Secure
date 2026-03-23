const express = require('express');

const { query } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { config } = require('../config');

function buildHealthRouter() {
  const router = express.Router();

  router.get('/', asyncHandler(async (req, res) => {
    const startedAt = Date.now();
    let database;

    try {
      await query('SELECT 1');
      database = { ok: true, latency_ms: Date.now() - startedAt };
    } catch (error) {
      database = {
        ok: false,
        latency_ms: Date.now() - startedAt,
        error: error.message,
      };
    }

    return success(res, {
      service: 'real-estate-secure-backend',
      runtime: 'node-express',
      environment: config.env,
      database,
      now: new Date().toISOString(),
    });
  }));

  const readinessHandler = asyncHandler(async (req, res) => {
    await query('SELECT 1');
    return success(res, {
      ready: true,
      version: '1.0.0',
      environment: config.env,
    });
  });

  router.get('/ready', readinessHandler);
  router._readinessHandler = readinessHandler;

  return router;
}

module.exports = { buildHealthRouter };

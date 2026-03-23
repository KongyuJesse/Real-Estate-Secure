const Redis = require('ioredis');

const { config } = require('../config');

let redis;

function getRedis() {
  if (!config.redisUrl) {
    return null;
  }
  if (!redis) {
    redis = new Redis(config.redisUrl, {
      lazyConnect: true,
      maxRetriesPerRequest: 2,
      enableReadyCheck: true,
    });
  }
  return redis;
}

async function connectRedis() {
  const client = getRedis();
  if (!client) {
    return null;
  }
  if (client.status === 'ready' || client.status === 'connect') {
    return client;
  }
  await client.connect().catch(() => null);
  return client;
}

module.exports = {
  connectRedis,
  getRedis,
};

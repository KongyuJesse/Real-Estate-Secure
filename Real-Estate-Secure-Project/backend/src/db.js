const { Pool } = require('pg');

const { config } = require('./config');

function createPool(connectionString) {
  return new Pool({
    connectionString,
    max: 30,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  });
}

const writePool = createPool(config.databaseUrl);
const readPool = config.databaseReadUrl
  ? createPool(config.databaseReadUrl)
  : writePool;

async function query(text, params = []) {
  return writePool.query(text, params);
}

async function readQuery(text, params = []) {
  return readPool.query(text, params);
}

async function withTransaction(callback) {
  const client = await writePool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function closePools() {
  await Promise.allSettled([
    writePool.end(),
    readPool === writePool ? Promise.resolve() : readPool.end(),
  ]);
}

module.exports = {
  closePools,
  pool: writePool,
  query,
  readPool,
  readQuery,
  withTransaction,
  writePool,
};

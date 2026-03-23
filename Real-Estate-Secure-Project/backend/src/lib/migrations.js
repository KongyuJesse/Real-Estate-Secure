const fs = require('fs/promises');
const path = require('path');

const { pool } = require('../db');

const projectRoot = path.resolve(__dirname, '..', '..', '..');
const migrationsDir = path.join(projectRoot, 'database', 'migrations');
const seedsDir = path.join(projectRoot, 'database', 'seeds');
const migrationTableName = 'schema_migrations';

async function listSqlFiles(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name)
    .sort((left, right) => left.localeCompare(right));
}

async function ensureMigrationTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${migrationTableName} (
      migration_name TEXT PRIMARY KEY,
      migration_kind TEXT NOT NULL CHECK (migration_kind IN ('migration', 'seed')),
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function listAppliedMigrations(client, kind) {
  const result = await client.query(
    `SELECT migration_name
       FROM ${migrationTableName}
      WHERE migration_kind = $1`,
    [kind],
  );
  return new Set(result.rows.map((row) => row.migration_name));
}

async function applySqlDirectory(directory, { kind, logger = console } = {}) {
  const files = await listSqlFiles(directory);
  const client = await pool.connect();

  try {
    await ensureMigrationTable(client);
    const applied = await listAppliedMigrations(client, kind);

    for (const fileName of files) {
      if (applied.has(fileName)) {
        logger.info?.(`${new Date().toISOString()} INFO Skipping ${fileName}; already applied`);
        continue;
      }

      const fullPath = path.join(directory, fileName);
      const sql = await fs.readFile(fullPath, 'utf8');
      if (!sql.trim()) {
        continue;
      }

      logger.info?.(`${new Date().toISOString()} INFO Applying ${fileName}`);
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          `INSERT INTO ${migrationTableName} (migration_name, migration_kind)
           VALUES ($1, $2)`,
          [fileName, kind],
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }
  } finally {
    client.release();
  }
}

async function runMigrations({ withSeeds = false, logger = console } = {}) {
  await applySqlDirectory(migrationsDir, { kind: 'migration', logger });
  if (withSeeds) {
    await applySqlDirectory(seedsDir, { kind: 'seed', logger });
  }
}

module.exports = {
  migrationsDir,
  migrationTableName,
  seedsDir,
  runMigrations,
};

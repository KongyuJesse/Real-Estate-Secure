const { pool } = require('../src/db');
const { runMigrations } = require('../src/lib/migrations');

async function main() {
  const withSeeds = process.argv.includes('--with-seeds');
  await runMigrations({ withSeeds, logger: console });
  console.log(
    `${new Date().toISOString()} INFO Database migrations completed${withSeeds ? ' with seeds' : ''}.`,
  );
}

main()
  .catch((error) => {
    console.error(`${new Date().toISOString()} ERROR Migration failed`);
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end().catch(() => {});
  });

// All configuration comes from environment variables (twelve-factor).
import { readFileSync } from 'node:fs';

export function loadConfig(env = process.env) {
  // A password can come from PGPASSWORD or, better, from a file (PGPASSWORD_FILE),
  // which is how Docker and Compose secrets hand it over.
  let pgPassword = env.PGPASSWORD;
  if (env.PGPASSWORD_FILE) {
    pgPassword = readFileSync(env.PGPASSWORD_FILE, 'utf8').trim();
  }
  return {
    port: Number(env.PORT || 3000),
    appEnv: env.APP_ENV || 'local',
    version: env.APP_VERSION || 'dev',
    // No PGHOST means "no PostgreSQL": orders are kept in memory.
    pg: env.PGHOST
      ? {
          host: env.PGHOST,
          port: Number(env.PGPORT || 5432),
          user: env.PGUSER || 'quickbite',
          database: env.PGDATABASE || 'quickbite',
          password: pgPassword,
        }
      : null,
    // No REDIS_URL means "no queue": the API cooks orders itself (a fake kitchen).
    redisUrl: env.REDIS_URL || null,
    kitchenSeconds: Number(env.KITCHEN_SECONDS || 3),
    // Only for running without Docker: serve the front end from this folder.
    webDir: env.WEB_DIR || null,
  };
}

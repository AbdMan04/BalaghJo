require('dotenv').config();
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
const crypto = require('crypto');
const cluster = require('cluster');
const os = require('os');
const app = require('./app');
const { connectDB } = require('./config/db');

process.on('unhandledRejection', (reason) => {
  console.error('[unhandledRejection]', reason);
});
process.on('uncaughtException', (err) => {
  console.error('[uncaughtException]', err);
});

const PORT = process.env.PORT || 4000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/balaghjo';

// JWT secret handling. A missing value would break every login (signing
// throws), so never refuse to boot here — otherwise a misconfigured env
// turns into a crashing deploy. Warn loudly instead, and only fall back to
// an ephemeral secret (sessions won't survive the next restart) when none
// is configured at all.
if (!process.env.JWT_SECRET) {
  console.warn(
    '[startup] WARNING: JWT_SECRET is not set. Generated a random ephemeral ' +
      'secret, so all sessions will be invalidated on the next restart. ' +
      'Set a strong JWT_SECRET (e.g. `openssl rand -hex 32`) in your environment.'
  );
  process.env.JWT_SECRET = crypto.randomBytes(32).toString('hex');
} else if (process.env.JWT_SECRET.length < 32) {
  console.warn(
    `[startup] WARNING: JWT_SECRET is only ${process.env.JWT_SECRET.length} ` +
      'characters long. Use a random secret of at least 32 characters ' +
      '(e.g. `openssl rand -hex 32`).'
  );
}

// Use every available CPU core so Node's single-threaded event loop isn't
// the ceiling. Workers share the same port (cluster handles the dispatch).
// Capped at 2 by default to stay inside a 512MB free-tier instance's RAM;
// raise it explicitly with WEB_CONCURRENCY when the box has more memory.
// Set DISABLE_CLUSTER=1 to force a single process.
const defaultWorkers = Math.min(os.cpus().length, 2);
const workerCount = Number(process.env.WEB_CONCURRENCY) || defaultWorkers;

if (cluster.isPrimary && !process.env.DISABLE_CLUSTER && workerCount > 1) {
  console.log(`[cluster] primary ${process.pid} forking ${workerCount} workers`);
  for (let i = 0; i < workerCount; i += 1) cluster.fork();
  cluster.on('exit', (worker, code, signal) => {
    console.error(`[cluster] worker ${worker.process.pid} exited (${signal || code}); restarting`);
    cluster.fork();
  });
} else {
  (async () => {
    try {
      await connectDB(MONGO_URI);
      app.listen(PORT, () => console.log(`[api] listening on http://localhost:${PORT}`));
    } catch (err) {
      console.error('[startup] failed:', err);
      process.exit(1);
    }
  })();
}

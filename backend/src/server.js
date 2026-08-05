require('dotenv').config();
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
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

// Fail fast instead of a confusing 401 storm: the JWT secret is mandatory
// and must be a strong random value (tokens are signed and verified with it).
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error(
    '[startup] JWT_SECRET must be set to a random string of at least 32 characters.'
  );
  process.exit(1);
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

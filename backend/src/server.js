require('dotenv').config();
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
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

(async () => {
  try {
    await connectDB(MONGO_URI);
    app.listen(PORT, () => console.log(`[api] listening on http://localhost:${PORT}`));
  } catch (err) {
    console.error('[startup] failed:', err);
    process.exit(1);
  }
})();

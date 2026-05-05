require('dotenv').config();
const app = require('./app');
const { connectDB } = require('./config/db');

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

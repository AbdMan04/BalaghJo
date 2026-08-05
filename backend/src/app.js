require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/authRoutes');
const reportRoutes = require('./routes/reportRoutes');
const notificationRoutes = require('./routes/notificationRoutes');

const app = express();

const isTest = process.env.NODE_ENV === 'test';

app.set('trust proxy', 1);

app.use(helmet());

// Compress JSON responses (map marker lists + summaries are re-polled by
// every device, so gzip cuts the bandwidth cost of foreground polling).
app.use(compression());

// NFR: global fallback limiter (per-route auth limiters are stricter).
// Read-only endpoints that back the app's foreground polling are exempt
// here (they're still auth-protected at the route level); otherwise a
// single device polling every few seconds would exhaust a per-IP bucket
// and lock real users out.
const readOnlyPaths = ['/health', '/api/reports/summary', '/api/reports/public'];
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 600,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => readOnlyPaths.includes(req.path),
  message: { error: 'Too many requests, please try again later.' },
});
// Skip the global limiter under tests (the auth/report suites hammer the
// same localhost IP hundreds of times per run).
if (!isTest) app.use(globalLimiter);

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, cb) {
      if (!origin) return cb(null, true);
      if (allowedOrigins.length === 0) return cb(null, true);
      if (allowedOrigins.includes(origin)) return cb(null, true);
      return cb(new Error('Origin not allowed by CORS'));
    },
    credentials: true,
  })
);
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

app.use('/uploads', express.static(path.resolve(process.env.UPLOAD_DIR || 'uploads')));

app.get('/health', (_req, res) => res.json({ ok: true, service: 'balaghjo-api' }));

app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/notifications', notificationRoutes);

app.use((err, _req, res, _next) => {
  console.error('[error]', err.stack || err.message);
  if (err.code === 'LIMIT_FILE_SIZE') return res.status(413).json({ error: 'Image too large' });
  if (err.message?.toLowerCase().includes('image')) return res.status(400).json({ error: err.message });
  if (err.name === 'ValidationError') return res.status(400).json({ error: err.message });
  if (err.name === 'CastError') return res.status(400).json({ error: 'Invalid id' });
  res.status(500).json({ error: err.message || 'Internal server error' });
});

module.exports = app;

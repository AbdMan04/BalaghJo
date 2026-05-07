require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

const authRoutes = require('./routes/authRoutes');
const reportRoutes = require('./routes/reportRoutes');

const app = express();

app.set('trust proxy', 1);

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

app.use((err, _req, res, _next) => {
  console.error('[error]', err.stack || err.message);
  if (err.code === 'LIMIT_FILE_SIZE') return res.status(413).json({ error: 'Image too large' });
  if (err.message?.toLowerCase().includes('image')) return res.status(400).json({ error: err.message });
  if (err.name === 'ValidationError') return res.status(400).json({ error: err.message });
  if (err.name === 'CastError') return res.status(400).json({ error: 'Invalid id' });
  res.status(500).json({ error: err.message || 'Internal server error' });
});

module.exports = app;

/*
- Auth controller — feature F1 (User Authentication).
- Handles the full citizen authentication lifecycle: registration via
- phone number (FR-1), credential verification and JWT issuance (FR-2),
- profile view and edit (FR-3), bcrypt password hashing (NFR-1), and
- 30-minute JWT expiry (NFR-2). New accounts are verified at
- registration, so no OTP code is required to log in.
- Login uses the Strategy pattern in ../strategies/identifierStrategy.js
- to resolve the submitted phone number.
 */
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { validationResult } = require('express-validator');
const User = require('../models/User');
const wrap = require('../utils/asyncHandler');
const { resolveIdentifierStrategy } = require('../strategies/identifierStrategy');

const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_REFRESH_TOKENS = 5;

function signToken(user) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      phone: user.phone,
      role: user.role,
      provider: user.provider,
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '30m' }
  );
}

function hashRefreshToken(raw) {
  return crypto.createHash('sha256').update(raw).digest('hex');
}

// Issue a fresh opaque refresh token; only the hash ever reaches the DB.
function issueRefreshToken() {
  const raw = crypto.randomBytes(32).toString('hex');
  return {
    raw,
    tokenHash: hashRefreshToken(raw),
    expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
  };
}

function addRefreshToken(user, token) {
  user.refreshTokens.push({ tokenHash: token.tokenHash, expiresAt: token.expiresAt });
  if (user.refreshTokens.length > MAX_REFRESH_TOKENS) {
    user.refreshTokens = user.refreshTokens.slice(-MAX_REFRESH_TOKENS);
  }
}

exports.register = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { firstName, lastName, password } = req.body;
  const phone = String(req.body.phone || '').trim();
  if (!phone) {
    return res.status(400).json({ error: 'Phone number is required' });
  }

  const existing = await User.findOne({ phone });
  if (existing) {
    return res.status(409).json({ error: 'Phone already registered' });
  }

  const passwordHash = await User.hashPassword(password);

  const user = await User.create({
    firstName,
    lastName,
    phone,
    passwordHash,
    provider: 'phone',
    role: 'user',
    isVerified: true,
  });

  const refresh = issueRefreshToken();
  addRefreshToken(user, refresh);
  await user.save();

  const token = signToken(user);
  res.status(201).json({ token, refreshToken: refresh.raw, user: user.toPublicJSON() });
});

exports.login = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const raw = String(req.body.identifier || '').trim();
  const { password } = req.body;
  const strategy = resolveIdentifierStrategy(raw);
  if (!strategy) return res.status(401).json({ error: 'Incorrect password' });

  const user = await User.findOne(strategy.toQuery(raw)).select('+passwordHash +refreshTokens');
  if (!user) return res.status(401).json({ error: 'Incorrect Phone Number!' });
  const ok = await user.comparePassword(password);
  if (!ok) return res.status(401).json({ error: 'Incorrect password' });

  const refresh = issueRefreshToken();
  addRefreshToken(user, refresh);
  await user.save();

  const token = signToken(user);
  res.json({ token, refreshToken: refresh.raw, user: user.toPublicJSON() });
});

// FR-2 session renewal: exchange an unexpired refresh token for a fresh
// access token + a rotated refresh token. Old token is dead on success.
exports.refresh = wrap(async (req, res) => {
  const raw = String(req.body.refreshToken || '').trim();
  if (!raw) return res.status(400).json({ error: 'refreshToken is required' });

  const tokenHash = hashRefreshToken(raw);
  const user = await User.findOne({
    refreshTokens: { $elemMatch: { tokenHash, expiresAt: { $gt: new Date() } } },
  }).select('+refreshTokens');
  if (!user) return res.status(401).json({ error: 'Invalid or expired refresh token' });

  user.refreshTokens = user.refreshTokens.filter((t) => t.tokenHash !== tokenHash);
  const refresh = issueRefreshToken();
  addRefreshToken(user, refresh);
  await user.save();

  res.json({ token: signToken(user), refreshToken: refresh.raw });
});

exports.logout = wrap(async (req, res) => {
  const raw = String(req.body.refreshToken || '').trim();
  if (raw) {
    const tokenHash = hashRefreshToken(raw);
    await User.updateOne({ _id: req.user.id }, { $pull: { refreshTokens: { tokenHash } } });
  }
  res.json({ ok: true });
});

exports.me = wrap(async (req, res) => {
  const user = await User.findById(req.user.id);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ user: user.toPublicJSON() });
});

exports.changePassword = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { currentPassword, newPassword } = req.body;
  if (currentPassword === newPassword) {
    return res.status(400).json({ error: 'New password must be different from current' });
  }

  const user = await User.findById(req.user.id).select('+passwordHash');
  if (!user) return res.status(404).json({ error: 'User not found' });

  const ok = await user.comparePassword(currentPassword);
  if (!ok) return res.status(401).json({ error: 'Current password is incorrect' });

  const newHash = await User.hashPassword(newPassword);
  // Password changed → all refresh tokens are now stale; the client must
  // re-authenticate once the current access token expires.
  await User.updateOne({ _id: user._id }, { $set: { passwordHash: newHash, refreshTokens: [] } });
  res.json({ ok: true });
});

exports.updateProfile = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { firstName, lastName, phone, currentPassword } = req.body;
  const update = {};
  if (typeof firstName === 'string') update.firstName = firstName.trim();
  if (typeof lastName === 'string') update.lastName = lastName.trim();

  // Phone is the login identifier, so changing it is guarded by a password
  // check — a stolen access token alone can't hijack the account.
  if (typeof phone === 'string') {
    const trimmed = phone.trim();
    if (trimmed !== req.user.phone) {
      const user = await User.findById(req.user.id).select('+passwordHash');
      if (!user) return res.status(404).json({ error: 'User not found' });
      const ok = await user.comparePassword(currentPassword);
      if (!ok) return res.status(401).json({ error: 'Current password is incorrect' });
    }
    update.phone = trimmed;
  }

  if (Object.keys(update).length === 0) {
    return res.status(400).json({ error: 'No fields to update' });
  }

  const user = await User.findByIdAndUpdate(req.user.id, update, { new: true, runValidators: true });
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ user: user.toPublicJSON() });
});

// FCM device-token registration (FR-7 push notifications). Called on app
// startup / login / logout so the backend can target the right devices.
exports.registerDeviceToken = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const token = String(req.body.token || '').trim();
  if (!token) return res.status(400).json({ error: 'Device token is required' });

  const user = await User.findByIdAndUpdate(
    req.user.id,
    { $addToSet: { deviceTokens: token } },
    { new: true, runValidators: true }
  ).select('deviceTokens');
  if (!user) return res.status(404).json({ error: 'User not found' });

  if (user.deviceTokens.length > 20) {
    user.deviceTokens = user.deviceTokens.slice(-20);
    await user.save();
  }
  res.json({ ok: true });
});

exports.unregisterDeviceToken = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const token = String(req.body.token || '').trim();
  if (token) {
    await User.findByIdAndUpdate(req.user.id, { $pull: { deviceTokens: token } });
  }
  res.json({ ok: true });
});

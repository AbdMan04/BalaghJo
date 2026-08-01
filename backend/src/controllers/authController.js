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
const { validationResult } = require('express-validator');
const User = require('../models/User');
const wrap = require('../utils/asyncHandler');
const { resolveIdentifierStrategy } = require('../strategies/identifierStrategy');

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

  const token = signToken(user);
  res.status(201).json({ token, user: user.toPublicJSON() });
});

exports.login = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const raw = String(req.body.identifier || '').trim();
  const { password } = req.body;
  const strategy = resolveIdentifierStrategy(raw);
  if (!strategy) return res.status(401).json({ error: 'Incorrect password' });

  const user = await User.findOne(strategy.toQuery(raw)).select('+passwordHash');
  const ok = user ? await user.comparePassword(password) : false;
  if (!user || !ok) return res.status(401).json({ error: 'Incorrect password' });

  const token = signToken(user);
  res.json({ token, user: user.toPublicJSON() });
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
  await User.updateOne({ _id: user._id }, { $set: { passwordHash: newHash } });
  res.json({ ok: true });
});

exports.updateProfile = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { firstName, lastName, phone } = req.body;
  const update = {};
  if (typeof firstName === 'string') update.firstName = firstName.trim();
  if (typeof lastName === 'string') update.lastName = lastName.trim();
  if (typeof phone === 'string') update.phone = phone.trim();

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

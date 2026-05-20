/*
- Auth controller — feature F1 (User Authentication).
- Handles the full citizen authentication lifecycle: registration with
  email or phone (FR-1), credential verification and JWT issuance (FR-2),
  profile view and edit (FR-3), bcrypt password hashing (NFR-1), and
  30-minute JWT expiry (NFR-2). Also handles 6-digit code verification
  (the code is logged to the backend console).
- Login uses the Strategy pattern in ../strategies/identifierStrategy.js
  to resolve whether the submitted identifier is an email or a phone.
 */
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const User = require('../models/User');
const wrap = require('../utils/asyncHandler');
const { resolveIdentifierStrategy } = require('../strategies/identifierStrategy');
const {
  generateCode,
  hashCode,
  compareCode,
  expiryFromNow,
  logSimulatedDelivery,
} = require('../utils/verificationCode');

function signToken(user) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      email: user.email,
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
  const email = req.body.email ? String(req.body.email).toLowerCase() : undefined;
  const phone = req.body.phone || undefined;

  if (!email && !phone) {
    return res.status(400).json({ error: 'Email or phone is required' });
  }

  const orFilters = [];
  if (email) orFilters.push({ email });
  if (phone) orFilters.push({ phone });
  const existing = await User.findOne({ $or: orFilters });
  if (existing) {
    if (email && existing.email === email) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    return res.status(409).json({ error: 'Phone already registered' });
  }

  const passwordHash = await User.hashPassword(password);
  const channel = email ? 'email' : 'phone';
  const recipient = email || phone;
  const code = generateCode();
  const verificationCodeHash = await hashCode(code);
  const verificationCodeExpiresAt = expiryFromNow();

  const user = await User.create({
    firstName,
    lastName,
    email,
    phone,
    passwordHash,
    provider: channel,
    role: 'user',
    verifiedChannel: channel,
    verificationCodeHash,
    verificationCodeExpiresAt,
  });

  logSimulatedDelivery(channel, recipient, code);

  const token = signToken(user);
  res.status(201).json({ token, user: user.toPublicJSON() });
});

exports.login = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const raw = String(req.body.identifier || req.body.email || '').trim();
  const { password } = req.body;
  const strategy = resolveIdentifierStrategy(raw);
  if (!strategy) return res.status(401).json({ error: 'Invalid credentials' });

  const user = await User.findOne(strategy.toQuery(raw)).select('+passwordHash');
  const ok = user ? await user.comparePassword(password) : false;
  if (!user || !ok) return res.status(401).json({ error: 'Invalid credentials' });

  const token = signToken(user);
  res.json({ token, user: user.toPublicJSON() });
});

exports.me = wrap(async (req, res) => {
  const user = await User.findById(req.user.id);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ user: user.toPublicJSON() });
});

exports.verify = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const code = String(req.body.code || '').trim();
  if (!/^\d{6}$/.test(code)) {
    return res.status(400).json({ error: 'Code must be 6 digits' });
  }

  const user = await User.findById(req.user.id).select(
    '+verificationCodeHash +verificationCodeExpiresAt'
  );
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.isVerified) return res.json({ user: user.toPublicJSON() });

  if (!user.verificationCodeHash || !user.verificationCodeExpiresAt) {
    return res.status(400).json({ error: 'No code on file. Request a new one.' });
  }
  if (user.verificationCodeExpiresAt.getTime() < Date.now()) {
    return res.status(400).json({ error: 'Code expired. Request a new one.' });
  }

  const ok = await compareCode(code, user.verificationCodeHash);
  if (!ok) return res.status(401).json({ error: 'Incorrect code' });

  user.isVerified = true;
  user.verificationCodeHash = undefined;
  user.verificationCodeExpiresAt = undefined;
  await user.save();
  res.json({ user: user.toPublicJSON() });
});

exports.resendCode = wrap(async (req, res) => {
  const user = await User.findById(req.user.id);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.isVerified) return res.json({ ok: true, alreadyVerified: true });

  const channel = user.verifiedChannel || (user.email ? 'email' : 'phone');
  const recipient = channel === 'email' ? user.email : user.phone;
  if (!recipient) {
    return res.status(400).json({ error: 'No verification destination on file' });
  }

  const code = generateCode();
  user.verificationCodeHash = await hashCode(code);
  user.verificationCodeExpiresAt = expiryFromNow();
  await user.save();

  logSimulatedDelivery(channel, recipient, code);
  res.json({ ok: true, channel });
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

const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const User = require('../models/User');
const wrap = require('../utils/asyncHandler');

function signToken(user) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      email: user.email,
      role: user.role,
      provider: user.provider,
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
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
  const user = await User.create({
    firstName,
    lastName,
    email,
    phone,
    passwordHash,
    provider: email ? 'email' : 'phone',
    role: 'user',
  });
  const token = signToken(user);
  res.status(201).json({ token, user: user.toPublicJSON() });
});

exports.login = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const raw = String(req.body.identifier || req.body.email || '').trim();
  const { password } = req.body;
  const looksLikeEmail = raw.includes('@');
  const query = looksLikeEmail ? { email: raw.toLowerCase() } : { phone: raw };

  const user = await User.findOne(query).select('+passwordHash');
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

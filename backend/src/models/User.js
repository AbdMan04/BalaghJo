const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    firstName: { type: String, required: true, trim: true },
    lastName: { type: String, required: true, trim: true },
    phone: { type: String, unique: true, sparse: true, trim: true },
    passwordHash: { type: String, required: true, select: false },
    provider: {
      type: String,
      enum: ['google', 'phone'],
      default: 'phone',
      required: true,
    },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
      required: true,
    },
    sentReports: { type: Number, default: 0 },
    solvedReports: { type: Number, default: 0 },
    isVerified: { type: Boolean, default: true },
    deviceTokens: { type: [String], default: [] },
    // Rotating refresh-token registry: only the sha256 hash is stored, so a
    // DB leak never exposes usable tokens. Selected explicitly in auth flows.
    refreshTokens: {
      type: [{ tokenHash: { type: String }, expiresAt: { type: Date } }],
      default: [],
      select: false,
    },
  },
  { timestamps: true }
);

userSchema.methods.comparePassword = function (plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

// Safety net: legacy accounts (pre-phone-login app versions) stored values
// like 'email' that aren't in the enum. Normalize before any save so the
// document is always valid — otherwise a bare save() during login/refresh
// throws a ValidationError and blocks legacy users from signing in.
userSchema.pre('validate', function (next) {
  if (!['google', 'phone'].includes(this.provider)) this.provider = 'phone';
  next();
});

const BCRYPT_ROUNDS = 12;

userSchema.statics.hashPassword = function (plain) {
  return bcrypt.hash(plain, BCRYPT_ROUNDS);
};

userSchema.methods.toPublicJSON = function () {
  return {
    id: this._id,
    firstName: this.firstName,
    lastName: this.lastName,
    phone: this.phone,
    provider: this.provider,
    role: this.role,
    sentReports: this.sentReports,
    solvedReports: this.solvedReports,
    isVerified: this.isVerified,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);

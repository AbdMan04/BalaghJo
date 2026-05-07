const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    firstName: { type: String, required: true, trim: true },
    lastName: { type: String, required: true, trim: true },
    email: { type: String, unique: true, sparse: true, lowercase: true, trim: true },
    phone: { type: String, unique: true, sparse: true, trim: true },
    passwordHash: { type: String, required: true, select: false },
    provider: {
      type: String,
      enum: ['email', 'google', 'phone'],
      default: 'email',
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
  },
  { timestamps: true }
);

userSchema.methods.comparePassword = function (plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

const BCRYPT_ROUNDS = 12;

userSchema.statics.hashPassword = function (plain) {
  return bcrypt.hash(plain, BCRYPT_ROUNDS);
};

userSchema.methods.toPublicJSON = function () {
  return {
    id: this._id,
    firstName: this.firstName,
    lastName: this.lastName,
    email: this.email,
    phone: this.phone,
    provider: this.provider,
    role: this.role,
    sentReports: this.sentReports,
    solvedReports: this.solvedReports,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);

/*
- audienceResolver — pure audience-resolution logic for admin broadcasts.
- Given an audience descriptor ({ type: all | category | user, category,
- userId, phone }) it returns the concrete list of recipient user ids.
- Kept out of the controller so recipient-count rules are unit-testable
- without spinning up an HTTP server.
 */
const mongoose = require('mongoose');
const User = require('../models/User');
const Report = require('../models/Report');
const { CATEGORIES } = require('../models/Report');

async function resolveAudience(audience) {
  const type = audience && audience.type ? audience.type : 'all';
  if (type === 'all') {
    return User.distinct('_id');
  }
  if (type === 'category') {
    if (!CATEGORIES.includes(audience.category)) return [];
    return Report.distinct('userId', { category: audience.category });
  }
  if (type === 'user') {
    const id = audience.userId;
    if (id && mongoose.isValidObjectId(id)) {
      return [new mongoose.Types.ObjectId(id)];
    }
    if (audience.phone) {
      const u = await User.findOne({ phone: String(audience.phone).trim() }).select('_id');
      return u ? [u._id] : [];
    }
    return [];
  }
  return [];
}

module.exports = { resolveAudience };

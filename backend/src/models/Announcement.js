/*
- Announcement model — admin broadcasts (mass messaging).
- One document per broadcast: the source message plus how it was targeted
  and how many recipients it reached. Recipient copies live as per-user
  Notification documents (type 'announcement') so the existing inbox and
  push pipeline stay the single fan-out path.
 */
const mongoose = require('mongoose');
const { CATEGORIES } = require('../config/constants');

const announcementSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 120 },
    body: { type: String, required: true, trim: true, maxlength: 2000 },
    audience: {
      type: { type: String, enum: ['all', 'category', 'user'], default: 'all' },
      category: { type: String, enum: CATEGORIES, default: null },
      userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
      phone: { type: String, default: null },
    },
    sentBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    recipients: { type: Number, default: 0 },
    pushed: { type: Number, default: 0 },
  },
  { timestamps: true }
);

announcementSchema.index({ createdAt: -1 });

announcementSchema.methods.toJSON = function () {
  return {
    id: this._id,
    title: this.title,
    body: this.body,
    audience: this.audience,
    sentBy: this.sentBy,
    recipients: this.recipients,
    pushed: this.pushed,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Announcement', announcementSchema);

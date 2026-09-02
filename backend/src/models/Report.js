/*
- Report model — persistence schema behind features F2, F3, F4, and F7.
- Stores citizen-submitted issues, category, photo URL, status, and
  an append-only statusHistory that drives the F4 status timeline on
  the report detail screen.
 */
const mongoose = require('mongoose');
const { STATUSES, CATEGORIES, STATUS_TRANSITIONS } = require('../config/constants');

const reportSchema = new mongoose.Schema(
  {
    reportId: { type: String, unique: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    category: { type: String, enum: CATEGORIES, required: true },
    title: { type: String, trim: true, default: '' },
    description: { type: String, required: true, maxlength: 2000 },
    photoUrl: { type: String, default: '' },
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] }, // [lng, lat]
    },
    address: { type: String, default: '' },
    status: { type: String, enum: STATUSES, default: 'pending' },
    statusChangedAt: { type: Date, default: null },
    // Severity score 0..1 from reportIntelligence.scorePriority at submit
    // time, so admins can triage urgent civic issues (safety keywords +
    // category baseline) without reading every description.
    priority: { type: Number, min: 0, max: 1, default: 0 },
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    estimatedFix: { type: Date },
    statusHistory: [
      {
        status: { type: String, enum: STATUSES },
        changedAt: { type: Date, default: Date.now },
        changedBy: { type: String, default: 'system' },
      },
    ],
  },
  { timestamps: true }
);

reportSchema.index({ location: '2dsphere' });
reportSchema.index({ location: '2dsphere', category: 1 });
reportSchema.index({ userId: 1, createdAt: -1 });
reportSchema.index({ userId: 1, status: 1, createdAt: -1 });
reportSchema.index({ status: 1, createdAt: -1 });
reportSchema.index({ category: 1, createdAt: -1 });
// Priority-sorted admin feed (sortBy=priority) is backed by this compound
// index; the cursor paginates on (priority, createdAt, _id).
reportSchema.index({ priority: -1, createdAt: -1, _id: -1 });
// Text index backing the admin report search (q=): word-based, index-backed
// instead of a collection-scanning case-insensitive $regex. Word/token
// matching (not arbitrary substring), which is fine for report titles,
// addresses and ticket numbers. Created on the deployed DB via
// `npm run sync-indexes`.
reportSchema.index(
  { title: 'text', description: 'text', address: 'text', reportId: 'text' },
  { name: 'search_text' }
);

// Atomic sequence used to mint unique reportIds. A single document in
// the counters collection is incremented with findOneAndUpdate, so two
// concurrent creates can never derive the same next value (the old
// "find max + 1" approach raced and depended on a create retry loop).
const counterSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  seq: { type: Number, default: 0 },
});
const Counter = mongoose.models.Counter || mongoose.model('Counter', counterSchema);

reportSchema.pre('save', async function (next) {
  if (!this.reportId) {
    const counter = await Counter.findOneAndUpdate(
      { _id: 'report' },
      { $inc: { seq: 1 } },
      { upsert: true, returnDocument: 'after' }
    );
    this.reportId = `RPT-${counter.seq.toString().padStart(4, '0')}`;
  }
  if (this.isNew) {
    this.statusHistory.push({ status: this.status, changedBy: 'user' });
  }
  next();
});

reportSchema.methods.toPublicJSON = function () {
  return {
    id: this._id,
    reportId: this.reportId,
    userId: this.userId,
    category: this.category,
    title: this.title,
    description: this.description,
    photoUrl: this.photoUrl,
    location: this.location,
    address: this.address,
    status: this.status,
    statusChangedAt: this.statusChangedAt,
    priority: this.priority,
    statusHistory: (this.statusHistory || []).map((h) => ({
      status: h.status,
      changedAt: h.changedAt,
      changedBy: h.changedBy,
    })),
    assignedTo: this.assignedTo,
    estimatedFix: this.estimatedFix,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

// Lean shape for list endpoints (map markers, nearby matches): exactly
// the fields the list UI consumes, so large collections stay small.
reportSchema.methods.toPublicSummary = function () {
  return {
    id: this._id,
    reportId: this.reportId,
    category: this.category,
    title: this.title,
    status: this.status,
    address: this.address,
    priority: this.priority,
    photoUrl: this.photoUrl,
    location: this.location,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Report', reportSchema);
module.exports.STATUSES = STATUSES;
module.exports.CATEGORIES = CATEGORIES;
module.exports.STATUS_TRANSITIONS = STATUS_TRANSITIONS;

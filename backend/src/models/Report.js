/*
- Report model — persistence schema behind features F2, F3, F4, and F7.
- Stores citizen-submitted issues, category, photo URL, status, and
  an append-only statusHistory that drives the F4 status timeline on
  the report detail screen.
 */
const mongoose = require('mongoose');

const STATUSES = ['pending', 'in_progress', 'resolved'];
const CATEGORIES = ['pothole', 'waste', 'lighting', 'other'];

// F4 / FR-16 controlled workflow: a report can only move forward
// through the lifecycle (Pending -> In Progress -> Resolved).
const STATUS_TRANSITIONS = {
  pending: ['in_progress'],
  in_progress: ['resolved'],
  resolved: [],
};

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

module.exports = mongoose.model('Report', reportSchema);
module.exports.STATUSES = STATUSES;
module.exports.CATEGORIES = CATEGORIES;
module.exports.STATUS_TRANSITIONS = STATUS_TRANSITIONS;

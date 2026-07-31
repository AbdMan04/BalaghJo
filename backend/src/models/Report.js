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
    reportId: { type: String, unique: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    category: { type: String, enum: CATEGORIES, required: true },
    title: { type: String, trim: true, default: '' },
    description: { type: String, required: true, maxlength: 2000 },
    photoUrl: { type: String, default: '' },
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] }, // [lng, lat]
    },
    address: { type: String, default: '' },
    status: { type: String, enum: STATUSES, default: 'pending', index: true },
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
reportSchema.index({ userId: 1, createdAt: -1 });

reportSchema.pre('save', async function (next) {
  if (!this.reportId) {
    const Report = mongoose.model('Report');
    const last = await Report.findOne({ reportId: /^RPT-\d+$/ })
      .sort({ reportId: -1 })
      .select('reportId')
      .lean();
    const lastSeq = last ? parseInt(last.reportId.slice(4), 10) : 2400;
    this.reportId = `RPT-${(lastSeq + 1).toString().padStart(4, '0')}`;
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

// F4 status lifecycle: apply a forward-only transition (FR-16).
// Rejects same-status no-ops and backwards/skipped jumps, and appends
// an entry to the append-only statusHistory timeline.
reportSchema.methods.setStatus = function (nextStatus, changedBy = 'system') {
  if (this.status === nextStatus) {
    return {
      ok: false,
      reason: 'already_current',
      error: `Report is already ${nextStatus}`,
    };
  }
  const allowed = STATUS_TRANSITIONS[this.status] || [];
  if (!allowed.includes(nextStatus)) {
    return {
      ok: false,
      reason: 'invalid_transition',
      error: `Invalid status transition: ${this.status} -> ${nextStatus}`,
    };
  }
  const previous = this.status;
  this.status = nextStatus;
  this.statusChangedAt = new Date();
  this.statusHistory.push({ status: nextStatus, changedBy });
  return { ok: true, previous };
};

module.exports = mongoose.model('Report', reportSchema);
module.exports.STATUSES = STATUSES;
module.exports.CATEGORIES = CATEGORIES;
module.exports.STATUS_TRANSITIONS = STATUS_TRANSITIONS;

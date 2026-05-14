const mongoose = require('mongoose');

const STATUSES = ['pending', 'in_progress', 'resolved'];
const CATEGORIES = ['pothole', 'waste', 'lighting', 'road_crack', 'other'];

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
    const count = await mongoose.model('Report').countDocuments();
    this.reportId = `RPT-${(2400 + count + 1).toString().padStart(4, '0')}`;
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
    assignedTo: this.assignedTo,
    estimatedFix: this.estimatedFix,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('Report', reportSchema);
module.exports.STATUSES = STATUSES;
module.exports.CATEGORIES = CATEGORIES;

const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, default: 'report_status' },
    report: { type: mongoose.Schema.Types.ObjectId, ref: 'Report', default: null },
    reportId: { type: String, default: '' },
    title: { type: String, default: '' },
    body: { type: String, default: '' },
    read: { type: Boolean, default: false },
  },
  { timestamps: true }
);

notificationSchema.index({ user: 1, read: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);

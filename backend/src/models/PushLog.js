/*
- PushLog model — the messaging delivery log behind FR-12 / FR-17 and the
  NFR-7 / NFR-9 latency measurements. One document per notification fan-out
  (a status change, an announcement, a new-report alert) records how many
  in-app notifications were generated, how many device tokens were targeted,
  how many FCM accepted, and the server-side timings:
    eventAt     — when the triggering event happened (e.g. status saved)
    startedAt   — when the fan-out began
    finishedAt  — when FCM answered (or the fan-out ended without a push)
  Device arrival time is logged on the phone ([perf] push_received), so
  end-to-end latency = device arrival − eventAt.
- Rows expire after 90 days so the collection can't grow without bound.
 */
const mongoose = require('mongoose');

const pushLogSchema = new mongoose.Schema(
  {
    type: { type: String, default: '' },
    reportId: { type: String, default: '' },
    status: { type: String, default: '' },
    recipients: { type: Number, default: 0 },
    notificationsCreated: { type: Number, default: 0 },
    tokens: { type: Number, default: 0 },
    sent: { type: Number, default: 0 },
    failed: { type: Number, default: 0 },
    deadTokens: { type: Number, default: 0 },
    eventAt: { type: Date, default: null },
    startedAt: { type: Date, required: true },
    finishedAt: { type: Date, required: true },
    durationMs: { type: Number, default: 0 },
  },
  { timestamps: true }
);

pushLogSchema.index({ createdAt: 1 }, { expireAfterSeconds: 90 * 24 * 60 * 60 });
pushLogSchema.index({ reportId: 1, createdAt: -1 });

module.exports = mongoose.model('PushLog', pushLogSchema);

/*
- notifyService — the single fan-out path for every notification a user
- receives (report-status updates, announcements). Creates the per-user
- Notification rows in chunks and fires one FCM multicast across every
- recipient's deduped device tokens. Best-effort by design: callers run
- it fire-and-forget so a slow push never serializes behind a response.
- Transient FCM failures are retried inside sendPush, and tokens FCM
- reports as permanently dead are pruned from their owning users.
- Every fan-out is recorded twice for the FR-12/FR-17 and NFR-7/NFR-9
- measurements: a timestamped [notif]/[push] console line and a PushLog
- document in MongoDB.
 */
const Notification = require('../models/Notification');
const PushLog = require('../models/PushLog');
const User = require('../models/User');
const { sendPush } = require('../config/firebase');

const CHUNK = 500;

async function notifyUsers({
  recipients,
  type,
  title,
  body,
  reportId = '',
  data = {},
  pushTitle,
  pushBody,
  eventAt,
}) {
  const startedAt = new Date();
  // Ticket number (RPT-xxxx) when the caller sent one in the push data,
  // otherwise whatever id the inbox row carries.
  const logReportId = String(data.reportId || reportId || '');
  const logStatus = String(data.status || '');

  for (let i = 0; i < recipients.length; i += CHUNK) {
    await Notification.insertMany(
      recipients.slice(i, i + CHUNK).map((user) => ({
        user,
        type,
        reportId,
        title,
        body,
      }))
    );
  }
  console.log(
    `[notif] ${startedAt.toISOString()} created=${recipients.length} type=${type}` +
      ` report=${logReportId || '-'} status=${logStatus || '-'}`
  );

  const owners = await User.find(
    { _id: { $in: recipients }, deviceTokens: { $ne: [] } },
    { deviceTokens: 1 }
  );
  const tokenOwners = new Map();
  for (const owner of owners) {
    for (const token of owner.deviceTokens || []) tokenOwners.set(token, owner._id);
  }
  const tokens = [...tokenOwners.keys()];

  let sent = 0;
  let deadTokens = [];
  if (tokens.length > 0) {
    // sentAt lets the device compute delivery latency from its own log.
    ({ sent, deadTokens } = await sendPush({
      tokens,
      title: pushTitle ?? title,
      body: pushBody ?? body,
      data: { ...data, sentAt: new Date().toISOString() },
    }));
  }
  const finishedAt = new Date();

  await recordDelivery({
    type,
    reportId: logReportId,
    status: logStatus,
    recipients: recipients.length,
    notificationsCreated: recipients.length,
    tokens: tokens.length,
    sent,
    failed: Math.max(tokens.length - sent, 0),
    deadTokens: deadTokens.length,
    eventAt: eventAt || startedAt,
    startedAt,
    finishedAt,
    durationMs: finishedAt - startedAt,
  });

  // FCM said some registrations are gone for good — drop them so future
  // fan-outs don't keep paying to reach ghosts.
  if (deadTokens.length > 0) {
    const ownerIds = [
      ...new Set(
        deadTokens.map((t) => tokenOwners.get(t)).filter(Boolean)
      ),
    ];
    if (ownerIds.length > 0) {
      await User.updateMany(
        { _id: { $in: ownerIds } },
        { $pull: { deviceTokens: { $in: deadTokens } } }
      );
    }
  }
  return { sent };
}

// Logging must never break delivery: a failed PushLog write is reported and
// swallowed.
async function recordDelivery(entry) {
  console.log(
    `[push] ${entry.finishedAt.toISOString()} type=${entry.type}` +
      ` report=${entry.reportId || '-'} status=${entry.status || '-'}` +
      ` recipients=${entry.recipients} tokens=${entry.tokens} sent=${entry.sent}` +
      ` failed=${entry.failed} dead=${entry.deadTokens} durationMs=${entry.durationMs}`
  );
  try {
    await PushLog.create(entry);
  } catch (err) {
    console.error('[push] failed to write PushLog:', err.message);
  }
}

module.exports = { notifyUsers };

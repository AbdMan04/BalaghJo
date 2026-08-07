/*
- notifyService — the single fan-out path for every notification a user
- receives (report-status updates, announcements). Creates the per-user
- Notification rows in chunks and fires one FCM multicast across every
- recipient's deduped device tokens. Best-effort by design: callers run
- it fire-and-forget so a slow push never serializes behind a response.
 */
const Notification = require('../models/Notification');
const User = require('../models/User');
const { sendPush } = require('../config/firebase');

const CHUNK = 500;

async function notifyUsers({ recipients, type, title, body, reportId = '', data = {}, pushTitle, pushBody }) {
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
  const owners = await User.find(
    { _id: { $in: recipients }, deviceTokens: { $ne: [] } },
    { deviceTokens: 1 }
  );
  const tokens = [...new Set(owners.flatMap((o) => o.deviceTokens || []))];
  if (tokens.length === 0) return { sent: 0 };
  return sendPush({ tokens, title: pushTitle ?? title, body: pushBody ?? body, data });
}

module.exports = { notifyUsers };

/*
- notifyService — the single fan-out path for every notification a user
- receives (report-status updates, announcements). Creates the per-user
- Notification rows in chunks and fires one FCM multicast across every
- recipient's deduped device tokens. Best-effort by design: callers run
- it fire-and-forget so a slow push never serializes behind a response.
- Transient FCM failures are retried inside sendPush, and tokens FCM
- reports as permanently dead are pruned from their owning users.
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
  const tokenOwners = new Map();
  for (const owner of owners) {
    for (const token of owner.deviceTokens || []) tokenOwners.set(token, owner._id);
  }
  const tokens = [...tokenOwners.keys()];
  if (tokens.length === 0) return { sent: 0 };
  const { sent, deadTokens } = await sendPush({
    tokens,
    title: pushTitle ?? title,
    body: pushBody ?? body,
    data,
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

module.exports = { notifyUsers };

/*
- Announcement controller — admin mass messaging.
- create(): resolves the audience into a concrete list of users, fans out a
  per-user Notification row (so announcements land in the existing inbox)
  and fires one FCM multicast push across every recipient's device tokens.
  Fan-out and push are best-effort, fire-and-forget after the announcement
  document is persisted, so a slow push never blocks the admin response.
- list(): broadcast history for the admin dashboard.
 */
const mongoose = require('mongoose');

const Announcement = require('../models/Announcement');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Report = require('../models/Report');
const { CATEGORIES } = require('../models/Report');
const { sendPush } = require('../config/firebase');
const wrap = require('../utils/asyncHandler');

const CHUNK = 500;

function toPublic(a) {
  return {
    id: a._id,
    title: a.title,
    body: a.body,
    audience: a.audience,
    recipients: a.recipients,
    pushed: a.pushed,
    createdAt: a.createdAt,
  };
}

// Resolve an audience descriptor into the concrete set of recipient ids.
async function resolveAudience(audience) {
  const type = audience && audience.type ? audience.type : 'all';
  if (type === 'all') {
    return User.distinct('_id');
  }
  if (type === 'category') {
    if (!CATEGORIES.includes(audience.category)) return [];
    // Distinct users who reported in this category, plus every user (a
    // broadcast is civic — everyone who reported anything in that category
    // is the intended audience; no PII is exposed).
    return Report.distinct('userId', { category: audience.category });
  }
  if (type === 'user') {
    // Either a raw ObjectId or (more admin-friendly) a phone number that
    // gets resolved to that user's id.
    const id = audience.userId;
    if (id && mongoose.isValidObjectId(id)) {
      return [new mongoose.Types.ObjectId(id)];
    }
    if (audience.phone) {
      const u = await User.findOne({ phone: String(audience.phone).trim() }).select('_id');
      return u ? [u._id] : [];
    }
    return [];
  }
  return [];
}

exports.create = wrap(async (req, res) => {
  const { title, body } = req.body;
  const audience = req.body.audience || {};
  if (!title || !String(title).trim()) {
    return res.status(400).json({ error: 'Announcement title is required' });
  }
  if (!body || !String(body).trim()) {
    return res.status(400).json({ error: 'Announcement message is required' });
  }

  const userIds = await resolveAudience(audience);
  if (userIds.length === 0) {
    return res.status(400).json({ error: 'Audience is empty' });
  }

  const announcement = await Announcement.create({
    title: String(title).trim(),
    body: String(body).trim(),
    audience: {
      type: audience.type || 'all',
      category: audience.category || null,
      userId: audience.userId || null,
      phone: audience.phone || null,
    },
    sentBy: req.user.id,
    recipients: userIds.length,
  });

  // Fire-and-forget fan-out: per-user Notification rows in chunks, then one
  // multicast push to every collected device token (deduped).
  void (async () => {
    try {
      for (let i = 0; i < userIds.length; i += CHUNK) {
        const slice = userIds.slice(i, i + CHUNK);
        await Notification.insertMany(
          slice.map((u) => ({
            user: u,
            type: 'announcement',
            report: null,
            reportId: '',
            title: announcement.title,
            body: announcement.body,
          }))
        );
      }
      const owners = await User.find(
        { _id: { $in: userIds }, deviceTokens: { $ne: [] } },
        { deviceTokens: 1 }
      );
      const tokens = [...new Set(owners.flatMap((o) => o.deviceTokens || []))];
      if (tokens.length) {
        const { sent } = await sendPush({
          tokens,
          title: announcement.title,
          body: announcement.body,
          data: { type: 'announcement' },
        });
        await Announcement.updateOne(
          { _id: announcement._id },
          { $set: { pushed: sent } }
        );
      }
    } catch (err) {
      console.error('[announcement] fan-out failed:', err.message);
    }
  })();

  res.status(201).json({ announcement: toPublic(announcement) });
});

exports.list = wrap(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const announcements = await Announcement.find()
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit)
    .populate('sentBy', 'firstName lastName');
  res.json({
    announcements: announcements.map((a) => ({
      ...toPublic(a),
      sentBy: a.sentBy
        ? `${a.sentBy.firstName ?? ''} ${a.sentBy.lastName ?? ''}`.trim()
        : 'Unknown',
    })),
  });
});

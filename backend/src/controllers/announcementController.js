/*
- Announcement controller — admin mass messaging.
- create(): resolves the audience into a concrete list of users, fans out a
  per-user Notification row (so announcements land in the existing inbox)
  and fires one FCM multicast push across every recipient's device tokens.
  Fan-out and push are best-effort, fire-and-forget after the announcement
  document is persisted, so a slow push never blocks the admin response.
- list(): broadcast history for the admin dashboard.
 */
const Announcement = require('../models/Announcement');
const { resolveAudience } = require('../services/audienceResolver');
const { notifyUsers } = require('../services/notifyService');
const wrap = require('../utils/asyncHandler');

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

  // Fire-and-forget fan-out: per-user Notification rows, then one multicast
  // push to every collected device token (deduped).
  void (async () => {
    try {
      const { sent } = await notifyUsers({
        recipients: userIds,
        type: 'announcement',
        title: announcement.title,
        body: announcement.body,
        data: { type: 'announcement' },
      });
      if (sent > 0) {
        await Announcement.updateOne(
          { _id: announcement._id },
          { $set: { pushed: sent } }
        );
      }
    } catch (err) {
      console.error('[announcement] fan-out failed:', err.message);
    }
  })();

  res.status(201).json({ announcement: announcement.toJSON() });
});

exports.list = wrap(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const announcements = await Announcement.find()
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit)
    .populate('sentBy', 'firstName lastName');
  res.json({
    announcements: announcements.map((a) => ({
      ...a.toJSON(),
      sentBy: a.sentBy
        ? `${a.sentBy.firstName ?? ''} ${a.sentBy.lastName ?? ''}`.trim()
        : 'Unknown',
    })),
  });
});

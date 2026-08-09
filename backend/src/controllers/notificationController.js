const Notification = require('../models/Notification');
const wrap = require('../utils/asyncHandler');

exports.list = wrap(async (req, res) => {
  const notifications = await Notification.find({ user: req.user.id })
    .sort({ createdAt: -1 })
    .limit(100);
  res.json({
    notifications: notifications.map((n) => ({
      id: n._id,
      type: n.type,
      reportId: n.reportId,
      title: n.title,
      body: n.body,
      read: n.read,
      createdAt: n.createdAt,
    })),
  });
});

exports.unreadCount = wrap(async (req, res) => {
  const unread = await Notification.countDocuments({
    user: req.user.id,
    read: false,
  });
  res.json({ unread });
});

exports.markRead = wrap(async (req, res) => {
  const { ids } = req.body;
  const list = Array.isArray(ids) ? ids.filter((x) => typeof x === 'string') : [];
  if (list.length > 0) {
    await Notification.updateMany(
      { user: req.user.id, _id: { $in: list } },
      { $set: { read: true } }
    );
  }
  res.json({ ok: true });
});

// Delete specific notifications (body { ids: [...] }) or all of them when
// no ids are given — used by the notifications screen's per-item and
// select-all delete flows. Always scoped to the authenticated user.
exports.remove = wrap(async (req, res) => {
  const { ids } = req.body || {};
  const list = Array.isArray(ids) ? ids.filter((x) => typeof x === 'string') : [];
  if (list.length > 0) {
    await Notification.deleteMany({ user: req.user.id, _id: { $in: list } });
  } else {
    await Notification.deleteMany({ user: req.user.id });
  }
  res.json({ ok: true });
});

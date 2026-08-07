/*
- Admin controller — dashboard-wide aggregates and user management.
- stats(): admin counterpart of the citizen summary, computed over every
  report in one $facet pipeline (single round-trip): totals, per-status
  buckets, per-category counts, and a 14-day creation trend.
- listUsers(): paginated, searchable user directory (no auth material).
- updateRole(): promote/demote an admin with two safety guards — an admin
  can't change their own role, and the last admin can't be demoted.
 */
const User = require('../models/User');
const Report = require('../models/Report');
const wrap = require('../utils/asyncHandler');
const { escapeRegExp } = require('../utils/regex');

const MAX_PAGE_SIZE = 100;

function parsePageSize(raw) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return 50;
  return Math.min(Math.max(1, Math.trunc(n)), MAX_PAGE_SIZE);
}

exports.stats = wrap(async (_req, res) => {
  const since = new Date(Date.now() - 13 * 24 * 60 * 60 * 1000);
  const [agg] = await Report.aggregate([
    {
      $facet: {
        total: [{ $count: 'n' }],
        pending: [{ $match: { status: 'pending' } }, { $count: 'n' }],
        inProgress: [{ $match: { status: 'in_progress' } }, { $count: 'n' }],
        resolved: [{ $match: { status: 'resolved' } }, { $count: 'n' }],
        byCategory: [
          { $group: { _id: '$category', count: { $sum: 1 } } },
          { $sort: { count: -1 } },
        ],
        daily: [
          { $match: { createdAt: { $gte: since } } },
          {
            $group: {
              _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
              count: { $sum: 1 },
            },
          },
          { $sort: { _id: 1 } },
        ],
        users: [{ $count: 'n' }],
      },
    },
  ]);
  const count = (arr) => (arr && arr.length ? arr[0].n : 0);
  res.json({
    stats: {
      total: count(agg.total),
      pending: count(agg.pending),
      inProgress: count(agg.inProgress),
      resolved: count(agg.resolved),
      active: count(agg.pending) + count(agg.inProgress),
      users: count(agg.users),
      categories: (agg.byCategory || []).map((c) => ({
        category: c._id,
        count: c.count,
      })),
      daily: (agg.daily || []).map((d) => ({ date: d._id, count: d.count })),
    },
  });
});

exports.listUsers = wrap(async (req, res) => {
  const { q } = req.query;
  const filter = {};
  if (q && typeof q === 'string') {
    const term = q.trim();
    if (term) {
      // Substring $regex is kept here (not a text index) so partial phone
      // numbers still match, and the user table is small/bounded. The term
      // is escaped so a crafted query can't inject regex or trigger
      // catastrophic backtracking (ReDoS).
      const rx = escapeRegExp(term);
      filter.$or = [
        { firstName: { $regex: rx, $options: 'i' } },
        { lastName: { $regex: rx, $options: 'i' } },
        { phone: { $regex: rx, $options: 'i' } },
      ];
    }
  }
  const limit = parsePageSize(req.query.limit);
  const users = await User.find(filter)
    .select('firstName lastName phone role sentReports solvedReports isVerified createdAt')
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit);
  res.json({
    users: users.map((u) => ({
      id: u._id,
      firstName: u.firstName,
      lastName: u.lastName,
      phone: u.phone || '',
      role: u.role,
      sentReports: u.sentReports,
      solvedReports: u.solvedReports,
      isVerified: u.isVerified,
      createdAt: u.createdAt,
    })),
  });
});

exports.updateRole = wrap(async (req, res) => {
  const { role } = req.body;
  if (!['user', 'admin'].includes(role)) {
    return res.status(400).json({ error: 'Role must be user or admin' });
  }
  if (req.params.id === req.user.id) {
    return res.status(400).json({ error: 'You cannot change your own role' });
  }
  const target = await User.findById(req.params.id);
  if (!target) return res.status(404).json({ error: 'User not found' });
  if (target.role === 'admin' && role === 'user') {
    const adminCount = await User.countDocuments({ role: 'admin' });
    if (adminCount <= 1) {
      return res.status(400).json({ error: 'Cannot demote the last admin' });
    }
  }
  await User.updateOne({ _id: target._id }, { $set: { role } });
  res.json({
    ok: true,
    user: {
      id: target._id,
      firstName: target.firstName,
      lastName: target.lastName,
      phone: target.phone || '',
      role,
    },
  });
});

module.exports = {
  stats: exports.stats,
  listUsers: exports.listUsers,
  updateRole: exports.updateRole,
};

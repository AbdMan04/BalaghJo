/*
- Report controller / features F2 (Issue Report Submission), F3 (Report
List & History).
- Owns creation, listing, lookup, and deletion of reports. Photo uploads
 (FR-5) are received via multer middleware and stored alongside the
  report.
 */
const { validationResult } = require('express-validator');
const Report = require('../models/Report');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { sendPush } = require('../config/firebase');
const wrap = require('../utils/asyncHandler');

const STATUS_LABELS = { pending: 'Pending', in_progress: 'In Progress', resolved: 'Resolved' };

exports.createReport = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { category, title, description, address, lat, lng } = req.body;
  const photoUrl = req.file ? `/uploads/${req.file.filename}` : '';

  const payload = {
    userId: req.user.id,
    category,
    title: title || '',
    description,
    address: address || '',
    location: {
      type: 'Point',
      coordinates: [Number(lng) || 0, Number(lat) || 0],
    },
    photoUrl,
  };

  let report;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      report = await Report.create(payload);
      break;
    } catch (err) {
      if (err && err.code === 11000 && err.keyPattern && err.keyPattern.reportId) {
        if (attempt === 2) throw err;
        continue;
      }
      throw err;
    }
  }

  await User.findByIdAndUpdate(req.user.id, { $inc: { sentReports: 1 } });
  res.status(201).json({ report: report.toPublicJSON() });
});

exports.listMyReports = wrap(async (req, res) => {
  const { status } = req.query;
  const filter = { userId: req.user.id };
  if (status && ['pending', 'in_progress', 'resolved'].includes(status)) filter.status = status;
  const reports = await Report.find(filter).sort({ createdAt: -1 });
  res.json({ reports: reports.map((r) => r.toPublicJSON()) });
});

exports.listPublicReports = wrap(async (req, res) => {
  const { status, category } = req.query;
  const filter = {};
  if (status && ['pending', 'in_progress', 'resolved'].includes(status)) filter.status = status;
  if (category && ['pothole', 'waste', 'lighting', 'other'].includes(category)) {
    filter.category = category;
  }
  const reports = await Report.find(filter)
    .select('reportId category title status address location photoUrl createdAt')
    .sort({ createdAt: -1 })
    .limit(500);
  res.json({
    reports: reports.map((r) => ({
      id: r._id,
      reportId: r.reportId,
      category: r.category,
      title: r.title || '',
      status: r.status,
      address: r.address || '',
      photoUrl: r.photoUrl || '',
      location: r.location,
      createdAt: r.createdAt,
    })),
  });
});

// Duplicate-submission guard: returns same-category reports within
// ~500m of the given point (no reporter PII). Used by the submit
// screen to warn the user that the issue may already be reported.
exports.nearbyReports = wrap(async (req, res) => {
  const { lat, lng, category } = req.body;
  const latN = Number(lat);
  const lngN = Number(lng);
  if (Number.isNaN(latN) || Number.isNaN(lngN)) {
    return res.status(400).json({ error: 'lat and lng are required' });
  }
  const filter = {
    location: {
      $nearSphere: {
        $geometry: { type: 'Point', coordinates: [lngN, latN] },
        $maxDistance: 500,
      },
    },
  };
  if (category && ['pothole', 'waste', 'lighting', 'other'].includes(category)) {
    filter.category = category;
  }
  const reports = await Report.find(filter)
    .select('reportId category title status address location photoUrl createdAt')
    .sort({ createdAt: -1 })
    .limit(20);
  res.json({
    reports: reports.map((r) => ({
      id: r._id,
      reportId: r.reportId,
      category: r.category,
      title: r.title || '',
      status: r.status,
      address: r.address || '',
      photoUrl: r.photoUrl || '',
      location: r.location,
      createdAt: r.createdAt,
    })),
  });
});

exports.getReport = wrap(async (req, res) => {
  const report = await Report.findById(req.params.id).populate('userId', 'firstName lastName phone');
  if (!report) return res.status(404).json({ error: 'Not found' });
  const isOwnerOrAdmin =
    report.userId._id.toString() === req.user.id || req.user.role === 'admin';
  const reporter = report.userId;
  const json = report.toPublicJSON();
  json.userId = reporter._id;
  json.reporter = isOwnerOrAdmin
    ? {
        fullName: `${reporter.firstName ?? ''} ${reporter.lastName ?? ''}`.trim(),
        phone: reporter.phone || '',
      }
    : {
        fullName: `${(reporter.firstName ?? '').slice(0, 1)}. ${reporter.lastName ?? ''}`.trim(),
        phone: '',
      };
  res.json({ report: json });
});

exports.deleteReport = wrap(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) return res.status(404).json({ error: 'Not found' });
  if (report.userId.toString() !== req.user.id && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  const wasResolved = report.status === 'resolved';
  const ownerId = report.userId;
  await report.deleteOne();
  const inc = { sentReports: -1 };
  if (wasResolved) inc.solvedReports = -1;
  await User.findByIdAndUpdate(ownerId, { $inc: inc });
  res.json({ ok: true });
});

exports.summary = wrap(async (req, res) => {
  const userId = req.user.id;
  const [total, resolved, active] = await Promise.all([
    Report.countDocuments({ userId }),
    Report.countDocuments({ userId, status: 'resolved' }),
    Report.countDocuments({ userId, status: { $in: ['pending', 'in_progress'] } }),
  ]);
  const recent = await Report.find({ userId }).sort({ createdAt: -1 }).limit(3);
  res.json({
    summary: { total, resolved, active },
    recent: recent.map((r) => r.toPublicJSON()),
  });
});

exports.updateStatus = wrap(async (req, res) => {
  const { status } = req.body;
  if (!['pending', 'in_progress', 'resolved'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }
  const report = await Report.findById(req.params.id);
  if (!report) return res.status(404).json({ error: 'Not found' });

  const previous = report.status;
  const wasResolved = previous === 'resolved';
  const result = report.setStatus(status, req.user.phone || req.user.id);
  if (!result.ok) return res.status(400).json({ error: result.error });

  await report.save();
  if (status === 'resolved' && !wasResolved) {
    await User.findByIdAndUpdate(report.userId, { $inc: { solvedReports: 1 } });
  }

  // FR-7: persist an in-app notification and fire an FCM push to the
  // reporter's registered devices. sendPush is a no-op until
  // FCM_SERVICE_ACCOUNT_PATH is configured.
  if (previous !== status) {
    const label = STATUS_LABELS[status] || status;
    try {
      await Notification.create({
        user: report.userId,
        type: 'report_status',
        report: report._id,
        reportId: report.reportId,
        title: `Report ${report.reportId}`,
        body: `Status changed to ${label}`,
      });
      const owner = await User.findById(report.userId).select('deviceTokens');
      if (owner && owner.deviceTokens && owner.deviceTokens.length) {
        sendPush({
          tokens: owner.deviceTokens,
          title: `Report ${report.reportId} — ${label}`,
          body: report.title ? report.title : 'Your report status changed',
          data: { type: 'report_status', reportId: report.reportId, status },
        }).catch((err) => console.error('[fcm] send failed:', err.message));
      }
    } catch (err) {
      console.error('[notif] failed to create notification:', err.message);
    }
  }

  // NFR-6 measurement: timestamped status-change log (server side).
  console.log(
    `[status-update] ${new Date().toISOString()} report=${report.reportId} ${previous} -> ${status} by=${req.user.phone || req.user.id}`
  );

  res.json({ report: report.toPublicJSON() });
});

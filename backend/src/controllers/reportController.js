/**
 * Report controller — features F2 (Issue Report Submission), F3 (Report
 * List & History), F4 partial (status history feed), and F7 (Map View
 * of Reports).
 *
 * Owns creation, listing, lookup, and deletion of reports. Photo uploads
 * (FR-5) are received via multer middleware and stored alongside the
 * report. The /all endpoint used by the community map (F7 — FR-18)
 * omits reporter PII so citizens cannot deanonymize each other from
 * the map.
 */
const { validationResult } = require('express-validator');
const Report = require('../models/Report');
const User = require('../models/User');
const wrap = require('../utils/asyncHandler');

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

exports.getReport = wrap(async (req, res) => {
  const report = await Report.findById(req.params.id).populate('userId', 'firstName lastName phone email');
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
        email: reporter.email || '',
      }
    : {
        fullName: `${(reporter.firstName ?? '').slice(0, 1)}. ${reporter.lastName ?? ''}`.trim(),
        phone: '',
        email: '',
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
  const wasResolved = report.status === 'resolved';
  report.status = status;
  report.statusHistory.push({ status, changedBy: req.user.email });
  await report.save();
  if (status === 'resolved' && !wasResolved) {
    await User.findByIdAndUpdate(report.userId, { $inc: { solvedReports: 1 } });
  }
  res.json({ report: report.toPublicJSON() });
});

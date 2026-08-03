/*
- Report controller / features F2 (Issue Report Submission), F3 (Report
List & History).
- Owns creation, listing, lookup, and deletion of reports. Photo uploads
 (FR-5) are received via multer middleware and stored alongside the
  report.
 */
const fs = require('fs');
const mongoose = require('mongoose');
const { validationResult } = require('express-validator');
const Report = require('../models/Report');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { sendPush } = require('../config/firebase');
const { uploader } = require('../config/cloudinary');
const wrap = require('../utils/asyncHandler');
const { STATUS_TRANSITIONS } = require('../models/Report');

const STATUS_LABELS = { pending: 'Pending', in_progress: 'In Progress', resolved: 'Resolved' };

// FR-5: store the uploaded photo on Cloudinary when configured; otherwise
// keep the local uploads/ path. The local file is a temp copy either way.
async function storePhoto(file) {
  if (!file) return '';
  if (uploader) {
    try {
      const result = await uploader.upload(file.path, { folder: 'balaghjo' });
      fs.unlink(file.path, () => {});
      return result.secure_url;
    } catch (err) {
      console.error('[cloudinary] upload failed:', err.message);
    }
  }
  return `/uploads/${file.filename}`;
}

function publicIdFromUrl(url) {
  const m = String(url).match(/\/image\/upload\/(?:v\d+\/)?(.+)$/);
  return m ? m[1].replace(/\.[a-z0-9]+$/i, '') : null;
}

exports.createReport = wrap(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    // multer already wrote the temp file to disk; drop it so failed
    // submissions don't leak orphaned uploads (F6).
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(400).json({ errors: errors.array() });
  }

  const { category, title, description, address, lat, lng } = req.body;
  let photoUrl = '';
  try {
    photoUrl = await storePhoto(req.file);
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    throw err;
  }

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
  try {
    report = await Report.create(payload);
  } catch (err) {
    // Report failed to persist; the uploaded photo is orphaned.
    if (req.file) fs.unlink(req.file.path, () => {});
    throw err;
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
  const { status, category, neLat, neLng, swLat, swLng } = req.query;
  const filter = {};
  if (status && ['pending', 'in_progress', 'resolved'].includes(status)) filter.status = status;
  if (category && ['pothole', 'waste', 'lighting', 'other'].includes(category)) {
    filter.category = category;
  }
  // C5: the map passes its viewport corners so we only return reports
  // inside the visible box (uses the 2dsphere index) instead of always
  // shipping up to 500 docs per open/pan/filter.
  const box = [
    Number(swLng), Number(swLat), Number(neLng), Number(neLat),
  ];
  if (box.every(Number.isFinite)) {
    filter.location = {
      $geoWithin: {
        $box: [[box[0], box[1]], [box[2], box[3]]],
      },
    };
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
  if (uploader && report.photoUrl) {
    const publicId = publicIdFromUrl(report.photoUrl);
    if (publicId) {
      uploader.destroy(publicId).catch((err) =>
        console.error('[cloudinary] destroy failed:', err.message)
      );
    }
  }
  const inc = { sentReports: -1 };
  if (wasResolved) inc.solvedReports = -1;
  await User.findByIdAndUpdate(ownerId, { $inc: inc });
  res.json({ ok: true });
});

exports.summary = wrap(async (req, res) => {
  const userId = new mongoose.Types.ObjectId(req.user.id);
  // C7: one round-trip instead of four — count the per-status buckets in
  // a single $facet pipeline (still served by the {userId, createdAt} index).
  const [agg] = await Report.aggregate([
    { $match: { userId } },
    {
      $facet: {
        total: [{ $count: 'n' }],
        resolved: [{ $match: { status: 'resolved' } }, { $count: 'n' }],
        active: [
          { $match: { status: { $in: ['pending', 'in_progress'] } } },
          { $count: 'n' },
        ],
      },
    },
  ]);
  const count = (arr) => (arr && arr.length ? arr[0].n : 0);
  const recent = await Report.find({ userId }).sort({ createdAt: -1 }).limit(3);
  res.json({
    summary: {
      total: count(agg.total),
      resolved: count(agg.resolved),
      active: count(agg.active),
    },
    recent: recent.map((r) => r.toPublicJSON()),
  });
});

exports.updateStatus = wrap(async (req, res) => {
  const { status } = req.body;
  if (!['pending', 'in_progress', 'resolved'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }

  // Which statuses may legally transition INTO `status`? e.g. resolved
  // can only come from in_progress. Used as the atomic match filter so
  // concurrent requests can never both apply the same transition.
  const allowedFrom = Object.keys(STATUS_TRANSITIONS).filter((from) =>
    STATUS_TRANSITIONS[from].includes(status)
  );

  // findOneAndUpdate is atomic: exactly one concurrent request wins the
  // conditional match (current status must be a valid predecessor), so
  // statusHistory can't get duplicate entries and solvedReports can't be
  // double-incremented by two racing admins.
  const report = await Report.findOneAndUpdate(
    { _id: req.params.id, status: { $in: allowedFrom } },
    {
      $set: {
        status,
        statusChangedAt: new Date(),
      },
      $push: { statusHistory: { status, changedBy: req.user.phone || req.user.id } },
    },
    { new: true }
  );

  if (!report) {
    const existing = await Report.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Not found' });
    if (existing.status === status) {
      return res.status(400).json({ error: `Report is already ${status}` });
    }
    return res.status(400).json({ error: `Invalid status transition: ${existing.status} -> ${status}` });
  }

  // Any applied transition to `resolved` necessarily came from a
  // non-resolved predecessor, so the increment is exactly correct.
  if (status === 'resolved') {
    await User.findByIdAndUpdate(report.userId, { $inc: { solvedReports: 1 } });
  }

  // FR-7: persist an in-app notification and fire an FCM push to the
  // reporter's registered devices. C6: fire-and-forget so the status
  // PATCH isn't serialized behind notification writes + push fan-out.
  const label = STATUS_LABELS[status] || status;
  void (async () => {
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
        await sendPush({
          tokens: owner.deviceTokens,
          title: `Report ${report.reportId} — ${label}`,
          body: report.title ? report.title : 'Your report status changed',
          data: { type: 'report_status', reportId: report.reportId, status },
        });
      }
    } catch (err) {
      console.error('[notif] failed to create notification:', err.message);
    }
  })();

  // NFR-6 measurement: timestamped status-change log (server side).
  console.log(
    `[status-update] ${new Date().toISOString()} report=${report.reportId} -> ${status} by=${req.user.phone || req.user.id}`
  );

  res.json({ report: report.toPublicJSON() });
});

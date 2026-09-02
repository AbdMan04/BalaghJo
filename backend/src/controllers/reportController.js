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
const { uploader } = require('../config/cloudinary');
const wrap = require('../utils/asyncHandler');
const { notifyUsers } = require('../services/notifyService');
const { scorePriority, rankDuplicates } = require('../services/reportIntelligence');
const { TtlCache } = require('../utils/ttlCache');
const { STATUSES, CATEGORIES, STATUS_TRANSITIONS } = require('../models/Report');

// Per-user summary is safe to cache for 15s because every write that can
// change it (create/delete/status update) invalidates the owner's entry.
const summaryCache = new TtlCache({ maxEntries: 2000 });
const SUMMARY_TTL_MS = 15_000;

// The public map list is global; cache it briefly and clear it on any write.
const publicCache = new TtlCache({ maxEntries: 200 });
const PUBLIC_TTL_MS = 5_000;

// My-reports list is polled every few seconds from the list screen but is
// only invalidated by that user's own writes; cache per (user, filter) and
// clear the whole bucket on any write so stale pages can't linger.
const myListCache = new TtlCache({ maxEntries: 500 });
const MY_LIST_TTL_MS = 5_000;

function invalidateUserSummary(userId) {
  summaryCache.delete(`summary:${userId.toString()}`);
}

function invalidatePublicLists() {
  publicCache.clear();
}

function invalidateMyLists() {
  myListCache.clear();
}

// Ownership/role guard shared by the detail and delete handlers.
function isOwnerOrAdmin(reportUserId, user) {
  return reportUserId.toString() === user.id || user.role === 'admin';
}

// Pagination (item 2): cursor-based paging for the report list endpoints.
// A cursor encodes `createdAtISO_id`; paging uses a (createdAt, _id) tuple
// comparison so identical timestamps can't skip or duplicate rows.
const DEFAULT_PAGE_SIZE = 500;
const MAX_PAGE_SIZE = 500;

function parsePageSize(raw) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return DEFAULT_PAGE_SIZE;
  return Math.min(Math.max(1, Math.trunc(n)), MAX_PAGE_SIZE);
}

function applyCursor(filter, before) {
  if (!before || typeof before !== 'string') return;
  const sep = before.lastIndexOf('_');
  if (sep <= 0) return;
  const ts = new Date(before.slice(0, sep));
  const id = before.slice(sep + 1);
  if (Number.isNaN(ts.getTime()) || !mongoose.isValidObjectId(id)) return;
  const oid = new mongoose.Types.ObjectId(id);
  filter.$or = [
    { createdAt: { $lt: ts } },
    { createdAt: ts, _id: { $lt: oid } },
  ];
}

function cursorFor(last) {
  return `${last.createdAt.toISOString()}_${last._id}`;
}

// Priority-sorted paging (sortBy=priority): a cursor encodes
// `priority:createdAtISO_id`, paged over the {priority, createdAt, _id}
// compound index, so the most urgent reports come first and pages stay
// stable even when several share the same score. The priority part of the
// cursor is delimited with '_' (never present in a float score or an ISO
// timestamp or an ObjectId), so it stays unambiguous — a ':' delimiter
// would collide with the colons inside the ISO timestamp.
function parsePriorityCursor(before) {
  if (!before || typeof before !== 'string') return null;
  const parts = before.split('_');
  if (parts.length !== 3) return null;
  const [priorityRaw, tsRaw, id] = parts;
  const priority = Number(priorityRaw);
  const ts = new Date(tsRaw);
  if (
    !Number.isFinite(priority) ||
    Number.isNaN(ts.getTime()) ||
    !mongoose.isValidObjectId(id)
  ) {
    return null;
  }
  return { priority, ts, id };
}

function applyPriorityCursor(filter, before) {
  const c = parsePriorityCursor(before);
  if (!c) return false;
  const oid = new mongoose.Types.ObjectId(c.id);
  filter.$or = [
    { priority: { $lt: c.priority } },
    { priority: c.priority, createdAt: { $lt: c.ts } },
    { priority: c.priority, createdAt: c.ts, _id: { $lt: oid } },
  ];
  return true;
}

function priorityCursorFor(last) {
  return `${last.priority}_${last.createdAt.toISOString()}_${last._id}`;
}

// FR-5: store the uploaded photo on Cloudinary when configured; otherwise
// keep the local uploads/ path. The local file is a temp copy either way.
// In production the local fallback is disabled: Render's filesystem is
// ephemeral, so a photo written there silently vanishes on the next
// redeploy. Fail the submission loudly instead of losing the image.
async function storePhoto(file) {
  if (!file) return '';
  if (uploader) {
    try {
      const result = await uploader.upload(file.path, { folder: 'balaghjo' });
      fs.unlink(file.path, () => {});
      return result.secure_url;
    } catch (err) {
      console.error('[cloudinary] upload failed:', err.message);
      if (process.env.NODE_ENV === 'production') {
        fs.unlink(file.path, () => {});
        throw new Error('Photo upload failed. Please try again.');
      }
    }
  } else if (process.env.NODE_ENV === 'production') {
    throw new Error('Photo storage is not configured. Please contact support.');
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

  // AI triage: score severity at submit time from category + text so the
  // admin feed can surface urgent issues first (generic classifier, no
  // external service — deterministic and offline).
  const { priority } = scorePriority({
    category,
    title: title || '',
    description,
  });

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
    priority,
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
  invalidateUserSummary(req.user.id);
  invalidatePublicLists();
  invalidateMyLists();

  // New-report notification: in-app row + FCM push to every admin's
  // registered devices (covers the web-dashboard push path). Fire-and-
  // forget so submission isn't serialized behind the admin fan-out.
  void (async () => {
    try {
      const admins = await User.find({ role: 'admin' }).select('_id');
      if (admins.length === 0) return;
      const placeName =
        report.address && report.address.trim()
          ? report.address.trim()
          : (report.title || '').trim() || 'موقع غير محدد';
      await notifyUsers({
        recipients: admins.map((a) => a._id),
        type: 'new_report',
        reportId: report.id,
        title: 'تحقق من هذا البلاغ',
        body: placeName,
        pushTitle: 'تحقق من هذا البلاغ',
        pushBody: placeName,
        data: { type: 'new_report', reportId: report.reportId },
      });
    } catch (err) {
      console.error('[notif] failed to notify admins:', err.message);
    }
  })();

  res.status(201).json({ report: report.toPublicJSON() });
});

exports.listMyReports = wrap(async (req, res) => {
  const { status } = req.query;
  const filter = { userId: req.user.id };
  if (status && STATUSES.includes(status)) filter.status = status;
  applyCursor(filter, req.query.before);
  const limit = parsePageSize(req.query.limit);
  const key = `my:${req.user.id}:${status || ''}:${limit}:${req.query.before || ''}`;
  const hit = myListCache.get(key, MY_LIST_TTL_MS);
  if (hit !== null) return res.json(hit);
  // Backward-compatible: without `limit`, returns the full list as before.
  const reports = await Report.find(filter)
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit + 1);
  const hasMore = reports.length > limit;
  const page = hasMore ? reports.slice(0, limit) : reports;
  const payload = {
    reports: page.map((r) => r.toPublicJSON()),
    nextCursor: hasMore ? cursorFor(page[page.length - 1]) : null,
  };
  myListCache.set(key, payload);
  res.json(payload);
});

exports.listPublicReports = wrap(async (req, res) => {
  const { status, category, neLat, neLng, swLat, swLng } = req.query;
  const filter = {};
  if (status && STATUSES.includes(status)) filter.status = status;
  if (category && CATEGORIES.includes(category)) filter.category = category;
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
  applyCursor(filter, req.query.before);
  const limit = parsePageSize(req.query.limit);
  const key = [
    'public',
    status || '',
    category || '',
    box.every(Number.isFinite) ? box.join(',') : 'none',
    limit,
    req.query.before || '',
  ].join('|');
  const payload = await cachedPublic(key, limit, filter);
  res.json(payload);
});

async function cachedPublic(key, limit, filter) {
  const hit = publicCache.get(key, PUBLIC_TTL_MS);
  if (hit !== null) return hit;
  const reports = await Report.find(filter)
    .select('reportId category title status address location photoUrl createdAt')
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit + 1);
  const hasMore = reports.length > limit;
  const page = hasMore ? reports.slice(0, limit) : reports;
  const payload = {
    reports: page.map((r) => r.toPublicSummary()),
    nextCursor: hasMore ? cursorFor(page[page.length - 1]) : null,
  };
  publicCache.set(key, payload);
  return payload;
}

// Duplicate-submission guard (semantic): returns the nearby reports most
// likely to be the same issue as the submission in progress, ranked by a
// fused text + location + category score (reportIntelligence) instead of
// the old same-category-within-500m test. `category` in the body is now a
// soft scoring hint, not a hard filter — two reporters who label the same
// pothole differently still get matched. Cross-category matches are the
// point of the upgrade, so no category filter is applied server-side.
const NEARBY_RADIUS_M = 2000;
const NEARBY_MAX_CANDIDATES = 30;
exports.nearbyReports = wrap(async (req, res) => {
  const { lat, lng } = req.body;
  const latN = Number(lat);
  const lngN = Number(lng);
  if (Number.isNaN(latN) || Number.isNaN(lngN)) {
    return res.status(400).json({ error: 'lat and lng are required' });
  }
  const candidates = await Report.find({
    location: {
      $nearSphere: {
        $geometry: { type: 'Point', coordinates: [lngN, latN] },
        $maxDistance: NEARBY_RADIUS_M,
      },
    },
  })
    .select('reportId category title description status address location photoUrl createdAt')
    .limit(NEARBY_MAX_CANDIDATES);

  const matches = rankDuplicates(candidates, {
    category: req.body.category,
    title: req.body.title || '',
    description: req.body.description || '',
    location: { type: 'Point', coordinates: [lngN, latN] },
  });

  const round3 = (n) => Math.round(n * 1000) / 1000;
  res.json({
    reports: matches.map(({ report, similarity, distanceMeters, signals }) => ({
      ...report.toPublicSummary(),
      similarity: round3(similarity),
      distanceMeters,
      signals: {
        text: round3(signals.text),
        location: round3(signals.location),
        category: signals.category,
      },
    })),
  });
});

// F5 / FR-13..15: admin report listing — paginated (50/page), filterable by
// status, category and geo area, with the submitter populated (owner/phone)
// so the dashboard row can show who filed each report. This is the admin
// counterpart of listMyReports; citizen endpoints stay unchanged.
exports.listAdminReports = wrap(async (req, res) => {
  const { status, category, q, neLat, neLng, swLat, swLng } = req.query;
  const byPriority = req.query.sortBy === 'priority';
  const filter = {};
  if (status && STATUSES.includes(status)) filter.status = status;
  if (category && CATEGORIES.includes(category)) filter.category = category;
  const box = [Number(swLng), Number(swLat), Number(neLng), Number(neLat)];
  if (box.every(Number.isFinite)) {
    filter.location = {
      $geoWithin: {
        $box: [[box[0], box[1]], [box[2], box[3]]],
      },
    };
  }
  if (q && typeof q === 'string') {
    const term = q.trim();
    if (term) {
      // Text-index search across title/description/address/reportId. Being
      // a top-level operator (not filter.$or) means the cursor pagination's
      // own filter.$or (applyCursor) no longer clobbers the search clause —
      // previously the term silently dropped on page 2+.
      filter.$text = { $search: term };
    }
  }
  if (byPriority) {
    applyPriorityCursor(filter, req.query.before);
  } else {
    applyCursor(filter, req.query.before);
  }
  const limit = parsePageSize(req.query.limit || 50);
  const reports = await Report.find(filter)
    .populate('userId', 'firstName lastName phone')
    .sort(byPriority ? { priority: -1, createdAt: -1, _id: -1 } : { createdAt: -1, _id: -1 })
    .limit(limit + 1);
  const hasMore = reports.length > limit;
  const page = hasMore ? reports.slice(0, limit) : reports;
  const payload = {
    reports: page.map((r) => {
      const json = r.toPublicJSON();
      const reporter = r.userId;
      json.reporter = reporter
        ? {
            fullName: `${reporter.firstName ?? ''} ${reporter.lastName ?? ''}`.trim(),
            phone: reporter.phone || '',
          }
        : { fullName: 'Unknown', phone: '' };
      return json;
    }),
    nextCursor: hasMore
      ? byPriority
        ? priorityCursorFor(page[page.length - 1])
        : cursorFor(page[page.length - 1])
      : null,
  };
  res.json(payload);
});

exports.getReport = wrap(async (req, res) => {
  // The detail lookup accepts either the Mongo _id or the human ticket
  // number (RPT-xxxx): older in-app notifications stored the ticket
  // string in their reportId field, so navigating from those must still
  // resolve to the report.
  const query = mongoose.isValidObjectId(req.params.id)
    ? { _id: req.params.id }
    : { reportId: req.params.id };
  const report = await Report.findOne(query).populate('userId', 'firstName lastName phone');
  if (!report) return res.status(404).json({ error: 'Not found' });
  const allowed = isOwnerOrAdmin(report.userId, req.user);
  const reporter = report.userId;
  const json = report.toPublicJSON();
  json.userId = reporter._id;
  json.reporter = allowed
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
  if (!isOwnerOrAdmin(report.userId, req.user)) {
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
  invalidateUserSummary(ownerId);
  invalidatePublicLists();
  invalidateMyLists();
  res.json({ ok: true });
});

exports.summary = wrap(async (req, res) => {
  const userId = new mongoose.Types.ObjectId(req.user.id);
  const key = `summary:${req.user.id}`;
  const hit = summaryCache.get(key, SUMMARY_TTL_MS);
  if (hit !== null) return res.json(hit);
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
        // The recent-3 list rides in the same pipeline (one round-trip).
        // Aggregation emits plain documents, so shape them with a manual
        // mapper rather than the Mongoose toPublicJSON method.
        recent: [{ $sort: { createdAt: -1, _id: -1 } }, { $limit: 3 }],
      },
    },
  ]);
  const count = (arr) => (arr && arr.length ? arr[0].n : 0);
  const recent = (agg.recent || []).map((d) => ({
    id: d._id,
    reportId: d.reportId,
    userId: d.userId,
    category: d.category,
    title: d.title,
    description: d.description,
    photoUrl: d.photoUrl,
    location: d.location,
    address: d.address,
    status: d.status,
    statusChangedAt: d.statusChangedAt,
    priority: d.priority,
    statusHistory: (d.statusHistory || []).map((h) => ({
      status: h.status,
      changedAt: h.changedAt,
      changedBy: h.changedBy,
    })),
    assignedTo: d.assignedTo,
    estimatedFix: d.estimatedFix,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
  }));
  const payload = {
    summary: {
      total: count(agg.total),
      resolved: count(agg.resolved),
      active: count(agg.active),
    },
    recent,
  };
  summaryCache.set(key, payload);
  res.json(payload);
});

exports.updateStatus = wrap(async (req, res) => {
  const { status } = req.body;
  if (!STATUSES.includes(status)) {
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
  invalidateUserSummary(report.userId);
  invalidatePublicLists();
  invalidateMyLists();

  // FR-7: persist an in-app notification and fire an FCM push to the
  // reporter's registered devices. C6: fire-and-forget so the status
  // PATCH isn't serialized behind notification writes + push fan-out.
  const placeName =
    report.address && report.address.trim() ? report.address.trim() : '';
  const isResolved = status === 'resolved';
  const title = isResolved
    ? placeName
      ? `تم حل المشكلة في ${placeName}`
      : 'تم حل المشكلة!'
    : 'جارٍ العمل على حل المشكلة';
  const body = isResolved ? 'سعدنا بخدمتك، استمتع بوقتك!' : 'تحقق من التقدم';
  void (async () => {
    try {
      await notifyUsers({
        recipients: [report.userId],
        type: 'report_status',
        reportId: report.id,
        title,
        body,
        pushTitle: title,
        pushBody: body,
        data: { type: 'report_status', reportId: report.reportId, status },
      });
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

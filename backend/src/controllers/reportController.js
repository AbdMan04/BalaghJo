const { validationResult } = require('express-validator');
const Report = require('../models/Report');
const User = require('../models/User');

exports.createReport = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { category, title, description, address, lat, lng } = req.body;
  const photoUrl = req.file ? `/uploads/${req.file.filename}` : '';

  const report = await Report.create({
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
  });

  await User.findByIdAndUpdate(req.user.id, { $inc: { sentReports: 1 } });
  res.status(201).json({ report: report.toPublicJSON() });
};

exports.listMyReports = async (req, res) => {
  const { status } = req.query;
  const filter = { userId: req.user.id };
  if (status && ['pending', 'in_progress', 'resolved'].includes(status)) filter.status = status;
  const reports = await Report.find(filter).sort({ createdAt: -1 });
  res.json({ reports: reports.map((r) => r.toPublicJSON()) });
};

exports.getReport = async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) return res.status(404).json({ error: 'Not found' });
  if (report.userId.toString() !== req.user.id && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.json({ report: report.toPublicJSON() });
};

exports.summary = async (req, res) => {
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
};

exports.updateStatus = async (req, res) => {
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
};

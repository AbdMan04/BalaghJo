const mongoose = require('mongoose');
const { uploader } = require('./cloudinary');

async function migrateUsers() {
  const Users = mongoose.connection.collection('users');
  const r1 = await Users.updateMany({ role: 'citizen' }, { $set: { role: 'user' } });
  const r2 = await Users.updateMany({ role: { $exists: false } }, { $set: { role: 'user' } });
  const r3 = await Users.updateMany({ provider: { $exists: false } }, { $set: { provider: 'phone' } });
  // Legacy values ('email', etc.) aren't valid enum entries; normalize them
  // so save()-based flows (login refresh-token persistence) don't throw.
  const r4 = await Users.updateMany(
    { provider: { $exists: true, $nin: ['google', 'phone'] } },
    { $set: { provider: 'phone' } }
  );
  const total = r1.modifiedCount + r2.modifiedCount + r3.modifiedCount + r4.modifiedCount;
  if (total > 0) console.log(`[db] migrated ${total} legacy user fields`);
}

async function migrateReports() {
  // assignedTo changed from String to ObjectId ref. Clear empty-string
  // legacy values so Mongoose can cast on read without errors.
  const Reports = mongoose.connection.collection('reports');
  const r = await Reports.updateMany(
    { assignedTo: '' },
    { $set: { assignedTo: null } }
  );
  if (r.modifiedCount > 0) {
    console.log(`[db] cleared ${r.modifiedCount} legacy empty assignedTo values`);
  }
}

// Seed the reportId counter so new RPT-* ids continue above the current
// maximum instead of restarting and colliding with existing reports.
// $max never lowers the stored sequence.
async function seedReportCounter() {
  const Reports = mongoose.connection.collection('reports');
  const Counters = mongoose.connection.collection('counters');
  const last = await Reports.find({ reportId: /^RPT-\d+$/ })
    .sort({ reportId: -1 })
    .limit(1)
    .project({ reportId: 1 })
    .next();
  if (last) {
    const seq = parseInt(last.reportId.slice(4), 10);
    const r = await Counters.updateOne(
      { _id: 'report' },
      { $max: { seq } },
      { upsert: true }
    );
    console.log(`[db] report counter seeded at ${seq}`);
  }
}

// Users are sometimes deleted directly from the database; their reports
// stay behind and keep showing on the map explorer. This runs on every
// boot (so the next deploy/restart cleans up automatically): remove any
// report whose owner no longer exists, and drop its Cloudinary photo.
async function cleanupOrphanReports() {
  const Reports = mongoose.connection.collection('reports');
  const Users = mongoose.connection.collection('users');
  const userIds = await Users.distinct('_id');
  const orphans = await Reports.find({ userId: { $nin: userIds } })
    .project({ reportId: 1, photoUrl: 1 })
    .limit(500)
    .toArray();
  if (orphans.length === 0) return;

  for (const o of orphans) {
    if (uploader && o.photoUrl && o.photoUrl.startsWith('http')) {
      const m = String(o.photoUrl).match(/\/image\/upload\/(?:v\d+\/)?(.+)$/);
      const publicId = m ? m[1].replace(/\.[a-z0-9]+$/i, '') : null;
      if (publicId) {
        uploader.destroy(publicId).catch((err) =>
          console.error('[cloudinary] destroy failed for orphan photo:', err.message)
        );
      }
    }
  }
  const r = await Reports.deleteMany({ _id: { $in: orphans.map((o) => o._id) } });
  console.log(`[db] deleted ${r.deletedCount} orphaned reports (owner removed)`);
}

async function connectDB(uri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  console.log('Connected!... :)');
  try {
    await migrateUsers();
    await migrateReports();
    await seedReportCounter();
    await cleanupOrphanReports();
  } catch (err) {
    console.error('[db] migration failed:', err.message);
  }
}

module.exports = { connectDB };

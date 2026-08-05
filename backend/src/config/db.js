const mongoose = require('mongoose');

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

async function connectDB(uri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  console.log('Connected!... :)');
  try {
    await migrateUsers();
    await migrateReports();
    await seedReportCounter();
  } catch (err) {
    console.error('[db] migration failed:', err.message);
  }
}

module.exports = { connectDB };

const mongoose = require('mongoose');

async function migrateUsers() {
  const Users = mongoose.connection.collection('users');
  const r1 = await Users.updateMany({ role: 'citizen' }, { $set: { role: 'user' } });
  const r2 = await Users.updateMany({ role: { $exists: false } }, { $set: { role: 'user' } });
  const r3 = await Users.updateMany({ provider: { $exists: false } }, { $set: { provider: 'phone' } });
  const total = r1.modifiedCount + r2.modifiedCount + r3.modifiedCount;
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

async function connectDB(uri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  console.log('Connected!... :)');
  try {
    await migrateUsers();
    await migrateReports();
  } catch (err) {
    console.error('[db] migration failed:', err.message);
  }
}

module.exports = { connectDB };

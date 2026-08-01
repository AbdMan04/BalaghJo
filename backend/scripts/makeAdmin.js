/*
- Dev-only utility for F4 testing: promote a citizen account to the
- admin role so the admin-only PATCH /api/reports/:id/status endpoint
- (which drives the status lifecycle) can be exercised.
- Usage: npm run make-admin -- <phone>
 */
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
const mongoose = require('mongoose');
const User = require('../src/models/User');

async function run() {
  const identifier = process.argv[2];
  if (!identifier) {
    console.error('Usage: npm run make-admin -- <phone>');
    process.exit(1);
  }

  const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/balaghjo';
  await mongoose.connect(MONGO_URI);

  const user = await User.findOneAndUpdate(
    { phone: identifier },
    { $set: { role: 'admin' } },
    { new: true }
  );
  if (!user) {
    console.error('User not found:', identifier);
    await mongoose.disconnect();
    process.exit(1);
  }

  console.log(`Promoted ${user.phone} to admin.`);
  await mongoose.disconnect();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

/*
- Ops utility: remove reports whose owner no longer exists.
- Users are sometimes deleted directly from the database; their reports
- stay behind and keep showing on the map explorer. This script deletes
- those orphaned reports (and their Cloudinary photos).
- Usage:
-   npm run cleanup-orphans           (dry run — shows what would be removed)
-   npm run cleanup-orphans -- --apply (actually deletes)
 */
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
const mongoose = require('mongoose');
const Report = require('../src/models/Report');
const User = require('../src/models/User');
const { uploader } = require('../src/config/cloudinary');

const APPLY = process.argv.includes('--apply');

function publicIdFromUrl(url) {
  const m = String(url).match(/\/image\/upload\/(?:v\d+\/)?(.+)$/);
  return m ? m[1].replace(/\.[a-z0-9]+$/i, '') : null;
}

async function run() {
  const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/balaghjo';
  await mongoose.connect(MONGO_URI);

  const userIds = (await User.find({}).select('_id')).map((u) => u._id);
  const orphans = await Report.find({ userId: { $nin: userIds } }).select('reportId photoUrl');

  if (orphans.length === 0) {
    console.log('No orphaned reports found. All clear.');
    await mongoose.disconnect();
    return;
  }

  console.log(`Found ${orphans.length} orphaned report(s):`);
  for (const r of orphans.slice(0, 10)) {
    console.log(`  ${r.reportId} (photo: ${r.photoUrl || 'none'})`);
  }
  if (orphans.length > 10) console.log(`  ... and ${orphans.length - 10} more`);

  if (!APPLY) {
    console.log('\nDry run — nothing deleted. Re-run with `--apply` to delete.');
    await mongoose.disconnect();
    return;
  }

  for (const r of orphans) {
    if (uploader && r.photoUrl) {
      const publicId = publicIdFromUrl(r.photoUrl);
      if (publicId) {
        uploader.destroy(publicId).catch((err) =>
          console.error(`[cloudinary] destroy failed for ${r.reportId}:`, err.message)
        );
      }
    }
  }
  const res = await Report.deleteMany({ _id: { $in: orphans.map((r) => r._id) } });
  console.log(`\nDeleted ${res.deletedCount} orphaned report(s).`);
  await mongoose.disconnect();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

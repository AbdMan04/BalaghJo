/*
- One-time maintenance utility (item 1): align the deployed collection's
- indexes with the Report schema. Removes the redundant single-field
- userId_1 / status_1 indexes that the schema no longer declares and
- creates the new covering compounds ({ userId, status, createdAt } and
- { location: '2dsphere', category }).
- Usage: npm run sync-indexes
 */
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
const mongoose = require('mongoose');
const Report = require('../src/models/Report');

async function run() {
  const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/balaghjo';
  await mongoose.connect(MONGO_URI);

  console.log('Existing indexes:');
  for (const i of await Report.collection.indexes()) {
    console.log(' ', i.name, JSON.stringify(i.key));
  }

  // syncIndexes() creates anything declared in the schema and drops any
  // indexes that are no longer declared (e.g. the old userId_1, status_1).
  await Report.syncIndexes();

  console.log('After syncIndexes():');
  for (const i of await Report.collection.indexes()) {
    console.log(' ', i.name, JSON.stringify(i.key));
  }

  await mongoose.disconnect();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

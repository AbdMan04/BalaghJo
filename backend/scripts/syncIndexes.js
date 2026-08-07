/*
- One-time maintenance utility (item 1): align deployed collections' indexes
- with their Mongoose schemas. syncIndexes() creates anything newly declared
- (e.g. the reports text index backing admin search) and drops indexes the
- schema no longer declares.
- Usage: npm run sync-indexes
 */
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
const mongoose = require('mongoose');
const Report = require('../src/models/Report');
const User = require('../src/models/User');
const Notification = require('../src/models/Notification');

const models = [Report, User, Notification];

async function run() {
  const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/balaghjo';
  await mongoose.connect(MONGO_URI);

  for (const model of models) {
    const name = model.collection.name;
    console.log(`\n[${name}] existing indexes:`);
    for (const i of await model.collection.indexes()) {
      console.log(' ', i.name, JSON.stringify(i.key));
    }

    await model.syncIndexes();

    console.log(`[${name}] after syncIndexes():`);
    for (const i of await model.collection.indexes()) {
      console.log(' ', i.name, JSON.stringify(i.key));
    }
  }

  await mongoose.disconnect();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

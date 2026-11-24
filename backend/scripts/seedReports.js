/*
- Test-data utility for the NFR-8 (dashboard load), NFR-10 (map render) and
  FR-19 (clustering) measurements, which call for seeded datasets of 100,
  500 and 1000 reports.
- Every seeded report belongs to one dedicated seed account, so the whole
  dataset can be removed again in one step without touching real reports.
- Usage:
    npm run seed -- 1000 --yes     add 1000 reports spread around Irbid
    npm run seed -- --clear --yes  remove the seed account and its reports
  Without --yes the script only prints what it would do. It writes to the
  database in MONGO_URI (backend/.env) — check that first: seeded reports are
  visible on the public map like any other report.
 */
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
const crypto = require('crypto');
const mongoose = require('mongoose');
const User = require('../src/models/User');
const Report = require('../src/models/Report');
const Notification = require('../src/models/Notification');
const { CATEGORIES } = require('../src/config/constants');

const SEED_PHONE = '0790000000';
const MAX_COUNT = 5000;
const CHUNK = 500;

// Irbid bounds, matching frontend/lib/core/map_config.dart.
const BOUNDS = { south: 32.42, north: 32.68, west: 35.68, east: 36.02 };
const CENTER = { lat: 32.5556, lng: 35.85 };

const DESCRIPTIONS = {
  pothole: 'Deep pothole in the right lane, cars swerving around it',
  waste: 'Garbage bins overflowing, waste piling up on the sidewalk',
  lighting: 'Street light not working, the road is completely dark at night',
  other: 'Damaged sidewalk tiles near the junction',
};

const rand = (min, max) => min + Math.random() * (max - min);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

// Most reports cluster around the city centre (realistic density for the
// clustering audit); the rest spread across the whole bounding box.
function randomPoint() {
  if (Math.random() < 0.7) {
    return {
      lat: clamp(CENTER.lat + rand(-0.04, 0.04), BOUNDS.south, BOUNDS.north),
      lng: clamp(CENTER.lng + rand(-0.05, 0.05), BOUNDS.west, BOUNDS.east),
    };
  }
  return { lat: rand(BOUNDS.south, BOUNDS.north), lng: rand(BOUNDS.west, BOUNDS.east) };
}

// 50% pending, 30% in progress, 20% resolved, with a history that matches.
function randomLifecycle(createdAt) {
  const roll = Math.random();
  const status = roll < 0.5 ? 'pending' : roll < 0.8 ? 'in_progress' : 'resolved';
  const history = [{ status: 'pending', changedAt: createdAt, changedBy: 'user' }];
  let at = createdAt;
  if (status !== 'pending') {
    at = new Date(at.getTime() + rand(1, 48) * 3600 * 1000);
    history.push({ status: 'in_progress', changedAt: at, changedBy: 'seed' });
  }
  if (status === 'resolved') {
    at = new Date(at.getTime() + rand(1, 72) * 3600 * 1000);
    history.push({ status: 'resolved', changedAt: at, changedBy: 'seed' });
  }
  return { status, history, statusChangedAt: status === 'pending' ? null : at };
}

async function seedUser() {
  let user = await User.findOne({ phone: SEED_PHONE });
  if (!user) {
    user = await User.create({
      firstName: 'Seed',
      lastName: 'Data',
      phone: SEED_PHONE,
      // Random, never printed: nobody can sign in as the seed account.
      passwordHash: await User.hashPassword(crypto.randomBytes(24).toString('hex')),
    });
  }
  return user;
}

async function seed(count, write) {
  console.log(`Would add ${count} reports owned by seed account ${SEED_PHONE}.`);
  if (!write) return;

  const user = await seedUser();
  const counter = await mongoose.connection
    .collection('counters')
    .findOneAndUpdate(
      { _id: 'report' },
      { $inc: { seq: count } },
      { upsert: true, returnDocument: 'after' }
    );
  // Driver 6 returns the document; older drivers wrap it in { value }.
  const lastSeq = (counter && (counter.seq ?? counter.value?.seq)) || count;
  let nextSeq = lastSeq - count + 1;

  const now = Date.now();
  let resolved = 0;
  for (let i = 0; i < count; i += CHUNK) {
    const docs = [];
    for (let j = i; j < Math.min(i + CHUNK, count); j += 1) {
      const category = pick(CATEGORIES);
      const point = randomPoint();
      const createdAt = new Date(now - rand(0, 60) * 24 * 3600 * 1000);
      const life = randomLifecycle(createdAt);
      if (life.status === 'resolved') resolved += 1;
      docs.push({
        reportId: `RPT-${String(nextSeq).padStart(4, '0')}`,
        userId: user._id,
        category,
        title: '',
        description: `[seed] ${DESCRIPTIONS[category]}`,
        photoUrl: '',
        location: { type: 'Point', coordinates: [point.lng, point.lat] },
        address: '',
        status: life.status,
        statusChangedAt: life.statusChangedAt,
        assignedTo: null,
        statusHistory: life.history,
        createdAt,
        updatedAt: life.statusChangedAt || createdAt,
      });
      nextSeq += 1;
    }
    await Report.collection.insertMany(docs, { ordered: false });
    console.log(`  inserted ${Math.min(i + CHUNK, count)}/${count}`);
  }
  await User.updateOne(
    { _id: user._id },
    { $inc: { sentReports: count, solvedReports: resolved } }
  );
  console.log(`Done: ${count} reports (${resolved} resolved). Remove with --clear --yes.`);
}

async function clear(write) {
  const user = await User.findOne({ phone: SEED_PHONE });
  if (!user) {
    console.log('No seed account found; nothing to remove.');
    return;
  }
  const n = await Report.countDocuments({ userId: user._id });
  console.log(`Would remove the seed account ${SEED_PHONE} and its ${n} reports.`);
  if (!write) return;
  await Report.deleteMany({ userId: user._id });
  await Notification.deleteMany({ user: user._id });
  await User.deleteOne({ _id: user._id });
  console.log('Removed.');
}

async function run() {
  const args = process.argv.slice(2);
  const write = args.includes('--yes');
  const clearMode = args.includes('--clear');
  const count = Number(args.find((a) => /^\d+$/.test(a)));

  if (!clearMode && !(count >= 1 && count <= MAX_COUNT)) {
    console.error(
      `Usage: npm run seed -- <count 1..${MAX_COUNT}> --yes | npm run seed -- --clear --yes`
    );
    process.exit(1);
  }

  const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/balaghjo';
  await mongoose.connect(MONGO_URI);
  const { host, name } = mongoose.connection;
  console.log(`Database: ${name} on ${host}`);

  if (clearMode) await clear(write);
  else await seed(count, write);

  if (!write) console.log('Dry run: nothing was written. Add --yes to apply.');
  await mongoose.disconnect();
}

run().catch(async (err) => {
  console.error(err);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongod;

async function startDb() {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  return mongod.getUri();
}

async function stopDb() {
  await mongoose.disconnect();
  if (mongod) await mongod.stop();
}

async function cleanDb() {
  if (mongoose.connection.readyState === 1) {
    // Clear documents, not the database: dropDatabase() also wipes the
    // collections' indexes, and Mongoose only auto-builds them at first
    // connect — so a dropped text index would make admin $text searches
    // fail for the rest of the suite.
    const Report = require('../src/models/Report');
    const User = require('../src/models/User');
    const Notification = require('../src/models/Notification');
    const Announcement = require('../src/models/Announcement');
    await Promise.all([
      Report.deleteMany({}),
      User.deleteMany({}),
      Notification.deleteMany({}),
      Announcement.deleteMany({}),
    ]);
  }
}

async function registerUser(agent, phone, password = 'secret123') {
  const res = await agent
    .post('/api/auth/register')
    .send({ firstName: 'Test', lastName: 'User', phone, password });
  expect(res.status).toBe(201);
  return res.body;
}

module.exports = { startDb, stopDb, cleanDb, registerUser };

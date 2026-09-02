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

// Creates a report in the citizen feed with a default pothole payload.
// `overrides` lets a caller change any field (category, description, etc.).
async function createReport(agent, token, overrides = {}) {
  return agent
    .post('/api/reports/')
    .set('Authorization', `Bearer ${token}`)
    .send({
      category: 'pothole',
      description: 'A large pothole on the main street',
      lat: 32.55,
      lng: 35.85,
      ...overrides,
    });
}

// Registers a user, promotes them to admin, and returns a fresh admin JWT.
async function adminTokenFor(agent, phone) {
  const { user } = await registerUser(agent, phone);
  const User = require('../src/models/User');
  await User.findByIdAndUpdate(user.id, { role: 'admin' });
  const login = await agent
    .post('/api/auth/login')
    .send({ identifier: phone, password: 'secret123' });
  expect(login.status).toBe(200);
  return login.body.token;
}

module.exports = { startDb, stopDb, cleanDb, registerUser, createReport, adminTokenFor };

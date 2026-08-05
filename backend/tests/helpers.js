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
    await mongoose.connection.dropDatabase();
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

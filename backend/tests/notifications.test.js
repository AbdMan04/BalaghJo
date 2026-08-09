const request = require('supertest');
const app = require('../src/app');
const Notification = require('../src/models/Notification');
const { startDb, stopDb, cleanDb, registerUser } = require('./helpers');

describe('notifications', () => {
  let agent;

  beforeAll(async () => {
    await startDb();
    agent = request(app);
  });

  afterAll(async () => {
    await stopDb();
  });

  beforeEach(async () => {
    await cleanDb();
  });

  test('unread-count requires authentication', async () => {
    const res = await agent.get('/api/notifications/unread-count');
    expect(res.status).toBe(401);
  });

  test('reports how many notifications are unread for the signed-in user', async () => {
    const { token, user } = await registerUser(agent, '0771006001');
    await Notification.insertMany([
      { user: user.id, type: 'report_status', title: 't', body: 'b', read: false },
      { user: user.id, type: 'report_status', title: 't', body: 'b', read: false },
      { user: user.id, type: 'report_status', title: 't', body: 'b', read: true },
    ]);

    const res = await agent
      .get('/api/notifications/unread-count')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.unread).toBe(2);
  });
});

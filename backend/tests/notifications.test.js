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

  test('delete requires authentication', async () => {
    const res = await agent.delete('/api/notifications');
    expect(res.status).toBe(401);
  });

  test('deletes only the selected notification ids for the signed-in user', async () => {
    const { token, user } = await registerUser(agent, '0771006002');
    const [first, second] = await Notification.insertMany([
      { user: user.id, type: 'report_status', title: 'a', body: 'b', read: true },
      { user: user.id, type: 'report_status', title: 'c', body: 'd', read: true },
      { user: user.id, type: 'report_status', title: 'e', body: 'f', read: true },
    ]);

    const res = await agent
      .delete('/api/notifications')
      .set('Authorization', `Bearer ${token}`)
      .send({ ids: [first.id, second.id] });

    expect(res.status).toBe(200);
    const remaining = await Notification.find({ user: user.id });
    expect(remaining).toHaveLength(1);
    expect(remaining[0].title).toBe('e');
  });

  test('deletes every notification for the signed-in user when no ids are given', async () => {
    const { token, user } = await registerUser(agent, '0771006003');
    await Notification.insertMany([
      { user: user.id, type: 'report_status', title: 'a', body: 'b', read: false },
      { user: user.id, type: 'report_status', title: 'c', body: 'd', read: true },
    ]);

    const res = await agent
      .delete('/api/notifications')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(await Notification.countDocuments({ user: user.id })).toBe(0);
  });
});

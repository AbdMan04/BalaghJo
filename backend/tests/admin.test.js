const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');
const Notification = require('../src/models/Notification');
const Announcement = require('../src/models/Announcement');
const { startDb, stopDb, cleanDb, registerUser } = require('./helpers');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

describe('admin dashboard (stats, users, announcements)', () => {
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

  async function adminTokenFor(phone) {
    const { user } = await registerUser(agent, phone);
    await User.findByIdAndUpdate(user.id, { role: 'admin' });
    const login = await agent
      .post('/api/auth/login')
      .send({ identifier: phone, password: 'secret123' });
    expect(login.status).toBe(200);
    return login.body.token;
  }

  async function userTokenFor(phone) {
    const { token } = await registerUser(agent, phone);
    return token;
  }

  async function createReport(token, category = 'pothole') {
    return agent
      .post('/api/reports/')
      .set('Authorization', `Bearer ${token}`)
      .send({
        category,
        description: 'A large pothole on the main street',
        lat: 32.55,
        lng: 35.85,
      });
  }

  test('admin endpoints reject non-admin tokens', async () => {
    const token = await userTokenFor('0772001001');
    for (const req of [
      agent.get('/api/admin/stats'),
      agent.get('/api/admin/users'),
      agent.get('/api/admin/announcements'),
      agent.post('/api/admin/announcements').send({ title: 'x', body: 'y' }),
      agent.delete('/api/admin/announcements/abc'),
      agent.delete('/api/admin/announcements'),
      agent.patch('/api/admin/users/abc/role').send({ role: 'admin' }),
    ]) {
      const res = await req.set('Authorization', `Bearer ${token}`);
      expect([401, 403]).toContain(res.status);
    }
  });

  test('stats aggregate reports across all users', async () => {
    const admin = await adminTokenFor('0791001001');
    const u1 = await userTokenFor('0771002001');
    const u2 = await userTokenFor('0771003001');
    await createReport(u1);
    await createReport(u1, 'waste');
    await createReport(u2);

    const res = await agent
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${admin}`);
    expect(res.status).toBe(200);
    const s = res.body.stats;
    expect(s.total).toBe(3);
    expect(s.pending).toBe(3);
    expect(s.resolved).toBe(0);
    expect(s.active).toBe(3);
    expect(s.users).toBe(3);
    const cats = Object.fromEntries(s.categories.map((c) => [c.category, c.count]));
    expect(cats.pothole).toBe(2);
    expect(cats.waste).toBe(1);
    expect(Array.isArray(s.daily)).toBe(true);
  });

  test('users list and role promotion/demotion', async () => {
    const admin = await adminTokenFor('0791001001');
    const { user } = await registerUser(agent, '0771004001');

    const list = await agent
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${admin}`);
    expect(list.status).toBe(200);
    expect(list.body.users.some((u) => u.phone === '0771004001')).toBe(true);

    const promote = await agent
      .patch(`/api/admin/users/${user.id}/role`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ role: 'admin' });
    expect(promote.status).toBe(200);
    expect(promote.body.user.role).toBe('admin');

    const demote = await agent
      .patch(`/api/admin/users/${user.id}/role`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ role: 'user' });
    expect(demote.status).toBe(200);
  });

  test('user search matches partial phone and treats regex metacharacters as literals', async () => {
    const admin = await adminTokenFor('0791001001');
    await registerUser(agent, '0771004002');

    const partial = await agent
      .get('/api/admin/users')
      .query({ q: '0771004' })
      .set('Authorization', `Bearer ${admin}`);
    expect(partial.status).toBe(200);
    expect(partial.body.users.some((u) => u.phone === '0771004002')).toBe(true);

    // A crafted term must not crash or reshape the query (ReDoS/injection).
    const hostile = await agent
      .get('/api/admin/users')
      .query({ q: '.*+?^${}()[]\\' })
      .set('Authorization', `Bearer ${admin}`);
    expect(hostile.status).toBe(200);
    expect(hostile.body.users).toHaveLength(0);
  });

  test('an admin cannot change their own role', async () => {
    const admin = await adminTokenFor('0791001001');
    const me = await User.findOne({ phone: '0791001001' });
    const res = await agent
      .patch(`/api/admin/users/${me.id}/role`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ role: 'user' });
    expect(res.status).toBe(400);
  });

  test('an admin can demote another admin while at least one remains', async () => {
    const adminA = await adminTokenFor('0791001001');
    const { user } = await registerUser(agent, '0791009001');
    await User.findByIdAndUpdate(user.id, { role: 'admin' });

    const res = await agent
      .patch(`/api/admin/users/${user.id}/role`)
      .set('Authorization', `Bearer ${adminA}`)
      .send({ role: 'user' });
    expect(res.status).toBe(200);
    expect(res.body.user.role).toBe('user');
  });

  test('broadcast to all users fans out notifications and records history', async () => {
    const admin = await adminTokenFor('0791001001');
    await userTokenFor('0771005001');
    await userTokenFor('0771006001');

    const res = await agent
      .post('/api/admin/announcements')
      .set('Authorization', `Bearer ${admin}`)
      .send({
        title: 'City water outage',
        body: 'Water will be cut on Sunday from 8am.',
        audience: { type: 'all' },
      });
    expect(res.status).toBe(201);
    expect(res.body.announcement.recipients).toBe(3);

    // Fan-out is fire-and-forget; give it a tick.
    await sleep(120);
    const notifs = await Notification.find({ type: 'announcement' });
    expect(notifs.length).toBe(3);

    const history = await agent
      .get('/api/admin/announcements')
      .set('Authorization', `Bearer ${admin}`);
    expect(history.status).toBe(200);
    expect(history.body.announcements.length).toBe(1);
    expect(history.body.announcements[0].title).toBe('City water outage');
  });

  test('broadcast to a category audience only targets those reporters', async () => {
    const admin = await adminTokenFor('0791001001');
    const u1 = await userTokenFor('0771007001');
    await userTokenFor('0771008001');
    await createReport(u1, 'pothole');

    const res = await agent
      .post('/api/admin/announcements')
      .set('Authorization', `Bearer ${admin}`)
      .send({
        title: 'Pothole campaign',
        body: 'We are fixing potholes this week.',
        audience: { type: 'category', category: 'pothole' },
      });
    expect(res.status).toBe(201);
    expect(res.body.announcement.recipients).toBe(1);

    await sleep(120);
    const notifs = await Notification.find({ type: 'announcement' });
    expect(notifs.length).toBe(1);

    await Announcement.deleteMany({});
    await Notification.deleteMany({});
  });

  test('an admin can delete a single announcement', async () => {
    const admin = await adminTokenFor('0791001001');
    await userTokenFor('0771005001');

    const created = await agent
      .post('/api/admin/announcements')
      .set('Authorization', `Bearer ${admin}`)
      .send({
        title: 'To remove',
        body: 'This one will be deleted.',
        audience: { type: 'all' },
      });
    expect(created.status).toBe(201);
    const id = created.body.announcement.id;

    const gone = await agent
      .delete(`/api/admin/announcements/${id}`)
      .set('Authorization', `Bearer ${admin}`);
    expect(gone.status).toBe(200);
    expect(gone.body.deleted).toBe(true);
    expect(gone.body.announcements).toHaveLength(0);

    const missing = await agent
      .delete(`/api/admin/announcements/${id}`)
      .set('Authorization', `Bearer ${admin}`);
    expect(missing.status).toBe(404);
  });

  test('an admin can delete all announcements', async () => {
    const admin = await adminTokenFor('0791001001');
    await userTokenFor('0771005001');

    for (const i of [1, 2]) {
      const res = await agent
        .post('/api/admin/announcements')
        .set('Authorization', `Bearer ${admin}`)
        .send({
          title: `Broadcast ${i}`,
          body: 'Body text',
          audience: { type: 'all' },
        });
      expect(res.status).toBe(201);
    }

    const cleared = await agent
      .delete('/api/admin/announcements')
      .set('Authorization', `Bearer ${admin}`);
    expect(cleared.status).toBe(200);
    expect(cleared.body.deleted).toBe(true);
    expect(cleared.body.announcements).toHaveLength(0);

    const history = await agent
      .get('/api/admin/announcements')
      .set('Authorization', `Bearer ${admin}`);
    expect(history.status).toBe(200);
    expect(history.body.announcements).toHaveLength(0);
  });
});

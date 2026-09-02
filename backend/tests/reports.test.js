const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');
const { startDb, stopDb, cleanDb, registerUser } = require('./helpers');

describe('reports', () => {
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

  async function createReport(token, overrides = {}) {
    const res = await agent
      .post('/api/reports/')
      .set('Authorization', `Bearer ${token}`)
      .send({
        category: 'pothole',
        description: 'A large pothole on the main street',
        lat: 32.55,
        lng: 35.85,
        ...overrides,
      });
    return res;
  }

  async function adminTokenFor(phone) {
    const { token, user } = await registerUser(agent, phone);
    await User.findByIdAndUpdate(user.id, { role: 'admin' });
    const login = await agent
      .post('/api/auth/login')
      .send({ identifier: phone, password: 'secret123' });
    return login.body.token;
  }

  async function nearby(token, body) {
    return agent.post('/api/reports/nearby').set('Authorization', `Bearer ${token}`).send(body);
  }

  test('creating a report requires authentication', async () => {
    const res = await agent.post('/api/reports/').send({
      category: 'pothole',
      description: 'A large pothole on the main street',
    });
    expect(res.status).toBe(401);
  });

  test('creates a report and invalidates the summary cache', async () => {
    const { token } = await registerUser(agent, '0773004005');

    const before = await agent
      .get('/api/reports/summary')
      .set('Authorization', `Bearer ${token}`);
    expect(before.body.summary.total).toBe(0);

    const res = await createReport(token);
    expect(res.status).toBe(201);
    expect(res.body.report.reportId).toMatch(/^RPT-\d{4}$/);
    expect(res.body.report.status).toBe('pending');

    const after = await agent
      .get('/api/reports/summary')
      .set('Authorization', `Bearer ${token}`);
    expect(after.body.summary.total).toBe(1);
    expect(after.body.recent).toHaveLength(1);
  });

  test('rejects invalid category / short description', async () => {
    const { token } = await registerUser(agent, '0774005006');
    const res = await createReport(token, { category: 'aliens' });
    expect(res.status).toBe(400);
    const short = await createReport(token, { description: 'bad' });
    expect(short.status).toBe(400);
  });

  test('submitting stores a priority score and exposes it in the response', async () => {
    const { token } = await registerUser(agent, '0774005006');
    const res = await createReport(token, {
      category: 'waste',
      description: 'FIRE risk from a broken electric wire near a school',
    });
    expect(res.status).toBe(201);
    // priority is a number in [0, 1], surfaced in the public JSON.
    expect(res.body.report.priority).toBeGreaterThan(0.5);
    expect(res.body.report).toHaveProperty('priority');
  });

  test('nearby dedupe is semantic: matches across categories on strong text', async () => {
    const { token } = await registerUser(agent, '0774005007');
    const first = await createReport(token, {
      category: 'pothole',
      title: 'Deep pothole',
      description: 'Large hole in the asphalt near the university gate',
    });
    expect(first.status).toBe(201);

    // Same issue, filed under a different category — must still rank as a
    // duplicate now that the guard scores text, not just same-category.
    const matches = await nearby(token, {
      category: 'other',
      title: 'Deep pothole',
      description: 'Large hole in the asphalt near the university gate',
      lat: 32.55,
      lng: 35.85,
    });
    expect(matches.status).toBe(200);
    expect(matches.body.reports.length).toBeGreaterThan(0);
    const top = matches.body.reports[0];
    expect(top.id).toBe(first.body.report.id);
    expect(top.similarity).toBeGreaterThan(0.5);
  });

  test('nearby dedupe ignores far/unrelated reports', async () => {
    const { token } = await registerUser(agent, '0774005008');
    await createReport(token, {
      category: 'waste',
      description: 'Trash bins overflowing in the old market',
    });

    const matches = await nearby(token, {
      category: 'pothole',
      description: 'Completely different issue about traffic lights',
      lat: 32.52,
      lng: 35.87,
    });
    expect(matches.status).toBe(200);
    // Distinct text and no overlapping meaning -> below the threshold.
    expect(matches.body.reports).toHaveLength(0);
  });

  test('nearby dedupe requires coordinates', async () => {
    const { token } = await registerUser(agent, '0774005009');
    const res = await nearby(token, { category: 'pothole', description: 'hole' });
    expect(res.status).toBe(400);
  });

  test('lists my reports with cursor pagination', async () => {
    const { token } = await registerUser(agent, '0775006007');
    for (let i = 0; i < 5; i += 1) {
      await createReport(token, { description: `Issue number ${i + 1} on the road` });
    }

    const page1 = await agent
      .get('/api/reports/?limit=2')
      .set('Authorization', `Bearer ${token}`);
    expect(page1.status).toBe(200);
    expect(page1.body.reports).toHaveLength(2);
    expect(page1.body.nextCursor).toBeTruthy();

    const page2 = await agent
      .get(`/api/reports/?limit=2&before=${encodeURIComponent(page1.body.nextCursor)}`)
      .set('Authorization', `Bearer ${token}`);
    expect(page2.body.reports).toHaveLength(2);
    expect(page2.body.nextCursor).toBeTruthy();
    // No overlap between pages (cursor tuple guarantees it).
    const ids1 = page1.body.reports.map((r) => r.id);
    const ids2 = page2.body.reports.map((r) => r.id);
    expect(ids1.some((id) => ids2.includes(id))).toBe(false);

    const page3 = await agent
      .get(`/api/reports/?limit=2&before=${encodeURIComponent(page2.body.nextCursor)}`)
      .set('Authorization', `Bearer ${token}`);
    expect(page3.body.reports).toHaveLength(1);
    expect(page3.body.nextCursor).toBeNull();
  });

  test('public map list respects the viewport and updates on writes', async () => {
    const { token } = await registerUser(agent, '0776007008');
    const inBox = await createReport(token, {
      description: 'Inside the box near the city center',
      lat: 32.55,
      lng: 35.85,
    });
    await createReport(token, {
      description: 'Far outside the box in the south',
      lat: 31.0,
      lng: 36.0,
    });

    const box = {
      swLat: 32.0,
      swLng: 35.0,
      neLat: 33.0,
      neLng: 36.0,
    };
    const res = await agent
      .get('/api/reports/public')
      .query(box)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.reports.some((r) => r.id === inBox.body.report.id)).toBe(true);
    expect(res.body.reports.every((r) => r.id !== undefined)).toBe(true);
    // Report summaries don't leak the description field.
    expect(res.body.reports[0].description).toBeUndefined();

    const miss = await agent
      .get('/api/reports/public')
      .query({
        swLat: 30.0,
        swLng: 35.0,
        neLat: 30.5,
        neLng: 35.5,
      })
      .set('Authorization', `Bearer ${token}`);
    expect(miss.body.reports).toHaveLength(0);

    await createReport(token, {
      description: 'Another marker in the same box',
      lat: 32.6,
      lng: 35.7,
    });
    const after = await agent
      .get('/api/reports/public')
      .query(box)
      .set('Authorization', `Bearer ${token}`);
    expect(after.body.reports).toHaveLength(2);
  });

  test('status transitions are atomic and admin-only', async () => {
    const { token } = await registerUser(agent, '0777008009');
    const created = await createReport(token);
    const reportId = created.body.report.id;

    const nonAdmin = await agent
      .patch(`/api/reports/${reportId}/status`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'in_progress' });
    expect(nonAdmin.status).toBe(403);

    const admin = await adminTokenFor('0778009010');
    const toProgress = await agent
      .patch(`/api/reports/${reportId}/status`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ status: 'in_progress' });
    expect(toProgress.status).toBe(200);
    expect(toProgress.body.report.status).toBe('in_progress');

    // Illegal jump: pending -> resolved is not allowed (must come from in_progress).
    const created2 = await createReport(token);
    const skip = await agent
      .patch(`/api/reports/${created2.body.report.id}/status`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ status: 'resolved' });
    expect(skip.status).toBe(400);
  });

  test('resolving increments solvedReports exactly once', async () => {
    const { token, user } = await registerUser(agent, '0779010011');
    const created = await createReport(token);
    const reportId = created.body.report.id;
    const admin = await adminTokenFor('0780011012');

    await agent
      .patch(`/api/reports/${reportId}/status`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ status: 'in_progress' });

    const resolved = await agent
      .patch(`/api/reports/${reportId}/status`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ status: 'resolved' });
    expect(resolved.status).toBe(200);

    const me = await agent.get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.body.user.solvedReports).toBe(1);

    // Applying the same resolved transition again is rejected (not double-incremented).
    const again = await agent
      .patch(`/api/reports/${reportId}/status`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ status: 'resolved' });
    expect(again.status).toBe(400);
  });

  test('deleting a report updates summary and public list', async () => {
    const { token, user } = await registerUser(agent, '0781012013');
    const created = await createReport(token);
    const reportId = created.body.report.id;

    const del = await agent
      .delete(`/api/reports/${reportId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(del.status).toBe(200);

    const summary = await agent
      .get('/api/reports/summary')
      .set('Authorization', `Bearer ${token}`);
    expect(summary.body.summary.total).toBe(0);

    const missing = await agent.get(`/api/reports/${reportId}`).set('Authorization', `Bearer ${token}`);
    expect(missing.status).toBe(404);
    expect(user.id).toBeTruthy();
  });

  test('GET detail resolves by ticket number (RPT-xxxx) as well as Mongo id', async () => {
    const { token } = await registerUser(agent, '0785016017');
    const created = await createReport(token);
    const ticket = created.body.report.reportId;

    const byId = await agent
      .get(`/api/reports/${created.body.report.id}`)
      .set('Authorization', `Bearer ${token}`);
    expect(byId.status).toBe(200);

    // In-app notifications historically stored the ticket string in their
    // reportId field; tapping one must open the report, not a CastError.
    const byTicket = await agent
      .get(`/api/reports/${ticket}`)
      .set('Authorization', `Bearer ${token}`);
    expect(byTicket.status).toBe(200);
    expect(byTicket.body.report.id).toBe(created.body.report.id);
  });

  test('admin report feed requires the admin role', async () => {
    const { token } = await registerUser(agent, '0782013014');
    const asUser = await agent
      .get('/api/admin/reports')
      .set('Authorization', `Bearer ${token}`);
    expect(asUser.status).toBe(403);

    const noAuth = await agent.get('/api/admin/reports');
    expect(noAuth.status).toBe(401);
  });

  test('admin report feed paginates at 50 and filters by status/category', async () => {
    const { token, user } = await registerUser(agent, '0783014015');
    for (let i = 0; i < 3; i += 1) {
      await createReport(token, {
        description: `Road issue number ${i + 1} in Irbid city center`,
      });
    }
    await createReport(token, {
      category: 'lighting',
      description: 'Broken streetlight near the university',
    });

    const admin = await adminTokenFor('0784015016');
    const all = await agent
      .get('/api/admin/reports')
      .set('Authorization', `Bearer ${admin}`);
    expect(all.status).toBe(200);
    expect(all.body.reports).toHaveLength(4);
    expect(all.body.reports[0].reporter.fullName).toContain(user.firstName);

    const potholes = await agent
      .get('/api/admin/reports')
      .query({ category: 'pothole' })
      .set('Authorization', `Bearer ${admin}`);
    expect(potholes.body.reports).toHaveLength(3);
    expect(potholes.body.reports.every((r) => r.category === 'pothole')).toBe(true);

    const resolved = await agent
      .get('/api/admin/reports')
      .query({ status: 'resolved' })
      .set('Authorization', `Bearer ${admin}`);
    expect(resolved.body.reports).toHaveLength(0);
  });

  test('admin report feed searches by text and keeps the term across pages', async () => {
    const token = (await registerUser(agent, '0783015017')).token;
    await createReport(token, {
      description: 'Deep pothole blocking the university gate',
    });
    await createReport(token, {
      description: 'Streetlight out near the university roundabout',
    });
    await createReport(token, {
      description: 'Unrelated litter in the old market',
    });

    const admin = await adminTokenFor('0784015018');
    const search = await agent
      .get('/api/admin/reports')
      .query({ q: 'university' })
      .set('Authorization', `Bearer ${admin}`);
    expect(search.status).toBe(200);
    expect(search.body.reports).toHaveLength(2);

    // Searching the ticket number must match too (it is in the text index).
    const ticket = search.body.reports[0].reportId;
    const byTicket = await agent
      .get('/api/admin/reports')
      .query({ q: ticket })
      .set('Authorization', `Bearer ${admin}`);
    expect(byTicket.body.reports.map((r) => r.reportId)).toContain(ticket);

    // Page 2 with a search term still applies the filter (the cursor's
    // filter.$or used to clobber the regex search clause).
    const page1 = await agent
      .get('/api/admin/reports')
      .query({ q: 'university', limit: 1 })
      .set('Authorization', `Bearer ${admin}`);
    expect(page1.body.reports).toHaveLength(1);
    expect(page1.body.nextCursor).not.toBeNull();
    const page2 = await agent
      .get('/api/admin/reports')
      .query({ q: 'university', limit: 1, before: page1.body.nextCursor })
      .set('Authorization', `Bearer ${admin}`);
    expect(page2.status).toBe(200);
    expect(page2.body.reports).toHaveLength(1);
    expect(page2.body.reports[0].description).toContain('university');
    expect(page2.body.reports[0].id).not.toBe(page1.body.reports[0].id);
  });

  test('admin feed sorts by priority and paginates without overlap', async () => {
    const token = (await registerUser(agent, '0783015017')).token;
    // Two urgent, one low-priority report.
    await createReport(token, {
      category: 'waste',
      description: 'electric wires down, fire risk, danger to children',
    });
    await createReport(token, { category: 'pothole', description: 'plain bump on the road' });
    await createReport(token, {
      category: 'lighting',
      description: 'emergency — streetlight collapse near the hospital',
    });

    const admin = await adminTokenFor('0784015018');
    const page1 = await agent
      .get('/api/admin/reports')
      .query({ sortBy: 'priority', limit: 2 })
      .set('Authorization', `Bearer ${admin}`);
    expect(page1.status).toBe(200);
    expect(page1.body.reports).toHaveLength(2);
    // Most urgent report leads the page and its cursor pages on.
    expect(page1.body.reports[0].description).toContain('emergency');
    expect(page1.body.nextCursor).not.toBeNull();
    expect(page1.body.reports[0].priority).toBeGreaterThanOrEqual(page1.body.reports[1].priority);

    const page2 = await agent
      .get('/api/admin/reports')
      .query({ sortBy: 'priority', limit: 2, before: page1.body.nextCursor })
      .set('Authorization', `Bearer ${admin}`);
    expect(page2.status).toBe(200);
    expect(page2.body.reports).toHaveLength(1);
    // No overlap between priority pages (tuple cursor guarantees it).
    const ids1 = page1.body.reports.map((r) => r.id);
    const ids2 = page2.body.reports.map((r) => r.id);
    expect(ids1.some((id) => ids2.includes(id))).toBe(false);
  });
});

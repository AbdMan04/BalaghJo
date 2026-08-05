const request = require('supertest');
const app = require('../src/app');
const { startDb, stopDb, cleanDb, registerUser } = require('./helpers');

describe('auth', () => {
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

  test('register returns access + refresh token and a public user', async () => {
    const res = await agent
      .post('/api/auth/register')
      .send({ firstName: 'Ahmad', lastName: 'Khaled', phone: '0771234567', password: 'secret123' });
    expect(res.status).toBe(201);
    expect(res.body.token).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.user.phone).toBe('0771234567');
    expect(res.body.user.passwordHash).toBeUndefined();
  });

  test('register rejects a duplicate phone with 409', async () => {
    await registerUser(agent, '0771234567');
    const res = await agent
      .post('/api/auth/register')
      .send({ firstName: 'A', lastName: 'B', phone: '0771234567', password: 'secret123' });
    expect(res.status).toBe(409);
  });

  test('register rejects an invalid phone format', async () => {
    const res = await agent
      .post('/api/auth/register')
      .send({ firstName: 'A', lastName: 'B', phone: '12345', password: 'secret123' });
    expect(res.status).toBe(400);
  });

  test('login returns tokens for valid credentials and 401 otherwise', async () => {
    await registerUser(agent, '0771112222');
    const ok = await agent
      .post('/api/auth/login')
      .send({ identifier: '0771112222', password: 'secret123' });
    expect(ok.status).toBe(200);
    expect(ok.body.token).toBeTruthy();
    expect(ok.body.refreshToken).toBeTruthy();

    const bad = await agent
      .post('/api/auth/login')
      .send({ identifier: '0771112222', password: 'wrong' });
    expect(bad.status).toBe(401);
  });

  test('/me returns the profile with a valid token', async () => {
    const { token } = await registerUser(agent, '0773334444');
    const res = await agent.get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user.phone).toBe('0773334444');
  });

  test('refresh rotates: old refresh dies, new refresh works', async () => {
    const { refreshToken: first } = await registerUser(agent, '0775556666');

    const rotated = await agent.post('/api/auth/refresh').send({ refreshToken: first });
    expect(rotated.status).toBe(200);
    expect(rotated.body.token).toBeTruthy();
    const second = rotated.body.refreshToken;
    expect(second).not.toBe(first);

    const replayed = await agent.post('/api/auth/refresh').send({ refreshToken: first });
    expect(replayed.status).toBe(401);

    const again = await agent.post('/api/auth/refresh').send({ refreshToken: second });
    expect(again.status).toBe(200);
  });

  test('refresh rejects a bogus token', async () => {
    const res = await agent.post('/api/auth/refresh').send({ refreshToken: 'not-a-token' });
    expect(res.status).toBe(401);
  });

  test('logout revokes the refresh token', async () => {
    const { token, refreshToken } = await registerUser(agent, '0777778888');
    const out = await agent
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${token}`)
      .send({ refreshToken });
    expect(out.status).toBe(200);

    const res = await agent.post('/api/auth/refresh').send({ refreshToken });
    expect(res.status).toBe(401);
  });

  test('changing the password revokes all refresh tokens', async () => {
    const { token, refreshToken } = await registerUser(agent, '0779990001');

    const change = await agent
      .patch('/api/auth/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: 'secret123', newPassword: 'newsecret456' });
    expect(change.status).toBe(200);

    const res = await agent.post('/api/auth/refresh').send({ refreshToken });
    expect(res.status).toBe(401);
  });

  test('changing phone requires the current password', async () => {
    const { token } = await registerUser(agent, '0771002003');

    const noPassword = await agent
      .patch('/api/auth/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ phone: '0771002004' });
    expect(noPassword.status).toBe(400);

    const wrongPassword = await agent
      .patch('/api/auth/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ phone: '0771002004', currentPassword: 'nope' });
    expect(wrongPassword.status).toBe(401);

    const ok = await agent
      .patch('/api/auth/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ phone: '0771002004', currentPassword: 'secret123' });
    expect(ok.status).toBe(200);
    expect(ok.body.user.phone).toBe('0771002004');
  });

  test('updating names only does not require a password', async () => {
    const { token } = await registerUser(agent, '0772003004');
    const res = await agent
      .patch('/api/auth/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ firstName: 'NewName' });
    expect(res.status).toBe(200);
    expect(res.body.user.firstName).toBe('NewName');
  });
});

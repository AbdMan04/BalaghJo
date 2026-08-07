const User = require('../src/models/User');
const Notification = require('../src/models/Notification');
const { startDb, stopDb, cleanDb } = require('./helpers');

jest.mock('../src/config/firebase', () => ({ sendPush: jest.fn() }));
const { sendPush } = require('../src/config/firebase');
const { notifyUsers } = require('../src/services/notifyService');

describe('notifyService', () => {
  beforeAll(async () => {
    await startDb();
  });

  afterAll(async () => {
    await stopDb();
  });

  beforeEach(async () => {
    await cleanDb();
    sendPush.mockReset();
  });

  test('persists notification rows and prunes dead device tokens', async () => {
    const u1 = await User.create({
      firstName: 'A',
      lastName: 'B',
      phone: '0771005001',
      passwordHash: 'x',
      deviceTokens: ['tok-live', 'tok-dead'],
    });
    const u2 = await User.create({
      firstName: 'C',
      lastName: 'D',
      phone: '0771005002',
      passwordHash: 'x',
      deviceTokens: ['tok-other'],
    });
    sendPush.mockResolvedValue({ sent: 2, deadTokens: ['tok-dead'] });

    const res = await notifyUsers({
      recipients: [u1._id, u2._id],
      type: 'announcement',
      title: 'Hello',
      body: 'World',
    });

    expect(res.sent).toBe(2);
    expect(await Notification.countDocuments()).toBe(2);
    expect((await User.findById(u1._id)).deviceTokens).toEqual(['tok-live']);
    expect((await User.findById(u2._id)).deviceTokens).toEqual(['tok-other']);
  });

  test('skips push entirely when no recipient has device tokens', async () => {
    const u1 = await User.create({
      firstName: 'A',
      lastName: 'B',
      phone: '0771005003',
      passwordHash: 'x',
    });

    const res = await notifyUsers({
      recipients: [u1._id],
      type: 'announcement',
      title: 't',
      body: 'b',
    });

    expect(sendPush).not.toHaveBeenCalled();
    expect(res.sent).toBe(0);
    expect(await Notification.countDocuments()).toBe(1);
  });

  test('reports sent count from sendPush and forwards deduped tokens', async () => {
    const u1 = await User.create({
      firstName: 'A',
      lastName: 'B',
      phone: '0771005004',
      passwordHash: 'x',
      deviceTokens: ['dup', 'dup', 'uniq'],
    });
    sendPush.mockResolvedValue({ sent: 2, deadTokens: [] });

    await notifyUsers({ recipients: [u1._id], type: 'announcement', title: 't', body: 'b' });

    expect(sendPush).toHaveBeenCalledWith(
      expect.objectContaining({ tokens: expect.arrayContaining(['dup', 'uniq']) })
    );
    expect(sendPush.mock.calls[0][0].tokens).toHaveLength(2);
  });
});

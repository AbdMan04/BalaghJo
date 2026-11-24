const { EventEmitter } = require('events');
const cacheBus = require('../src/utils/cacheBus');

describe('cacheBus', () => {
  test('publish runs local subscribers synchronously', () => {
    const seen = [];
    cacheBus.subscribe('test-local', (p) => seen.push(p));
    cacheBus.publish('test-local', { userId: 'u1' });
    expect(seen).toEqual([{ userId: 'u1' }]);
  });

  test('events relayed from a sibling worker reach local subscribers', () => {
    const seen = [];
    cacheBus.subscribe('test-relay', (p) => seen.push(p));
    cacheBus._receive({ __cacheBus: 'test-relay', payload: { userId: 'u2' } });
    cacheBus._receive({ unrelated: true });
    expect(seen).toEqual([{ userId: 'u2' }]);
  });

  test('the primary relays an event to every other worker, not the sender', () => {
    const fakeCluster = new EventEmitter();
    const mkWorker = () => ({ send: jest.fn(), isConnected: () => true });
    const a = mkWorker();
    const b = mkWorker();
    const c = mkWorker();
    fakeCluster.workers = { 1: a, 2: b, 3: c };
    cacheBus.attachPrimaryRelay(fakeCluster);

    const msg = { __cacheBus: 'report-caches', payload: { userId: 'u3' } };
    fakeCluster.emit('message', a, msg);
    fakeCluster.emit('message', a, { somethingElse: 1 });

    expect(a.send).not.toHaveBeenCalled();
    expect(b.send).toHaveBeenCalledWith(msg);
    expect(c.send).toHaveBeenCalledWith(msg);
    expect(b.send).toHaveBeenCalledTimes(1);
  });
});

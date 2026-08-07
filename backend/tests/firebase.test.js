const mockSendEach = jest.fn();

jest.mock('firebase-admin', () => ({
  cert: jest.fn((c) => c),
  initializeApp: jest.fn(),
}));
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast: mockSendEach }),
}));

process.env.FCM_SERVICE_ACCOUNT_JSON = JSON.stringify({ project_id: 'test-project' });

const { sendPush } = require('../src/config/firebase');

const TOKENS = ['tok-1', 'tok-2', 'tok-3'];

function batchResult(tokens, failures) {
  // failures: array of { index, code }
  const byIndex = new Map(failures.map((f) => [f.index, f.code]));
  const responses = tokens.map((_, index) => ({
    success: !byIndex.has(index),
    error: byIndex.has(index) ? { code: byIndex.get(index) } : undefined,
  }));
  const failureCount = responses.filter((r) => !r.success).length;
  return { responses, successCount: tokens.length - failureCount, failureCount };
}

describe('sendPush', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    mockSendEach.mockReset();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('sends every token once when the first attempt succeeds', async () => {
    mockSendEach.mockResolvedValue(batchResult(TOKENS, []));

    const res = await sendPush({ tokens: TOKENS, title: 't', body: 'b' });

    expect(mockSendEach).toHaveBeenCalledTimes(1);
    expect(res.sent).toBe(3);
    expect(res.deadTokens).toEqual([]);
  });

  test('retries a transient failure with backoff and counts the late success', async () => {
    mockSendEach
      .mockResolvedValueOnce(
        batchResult(TOKENS, [{ index: 1, code: 'messaging/server-unavailable' }])
      )
      .mockResolvedValueOnce(batchResult([TOKENS[1]], []));

    const pending = sendPush({ tokens: TOKENS, title: 't', body: 'b' });
    await jest.advanceTimersByTimeAsync(1000);
    const res = await pending;

    expect(mockSendEach).toHaveBeenCalledTimes(2);
    expect(mockSendEach).toHaveBeenLastCalledWith(
      expect.objectContaining({ tokens: [TOKENS[1]] })
    );
    expect(res.sent).toBe(3);
    expect(res.deadTokens).toEqual([]);
  });

  test('gives up after max attempts on persistent transient failures', async () => {
    const allFail = batchResult(
      TOKENS,
      TOKENS.map((_, index) => ({ index, code: 'messaging/internal-error' }))
    );
    mockSendEach.mockResolvedValue(allFail);

    const pending = sendPush({ tokens: TOKENS, title: 't', body: 'b' });
    await jest.advanceTimersByTimeAsync(1000);
    await jest.advanceTimersByTimeAsync(2000);
    const res = await pending;

    expect(mockSendEach).toHaveBeenCalledTimes(3);
    expect(res.sent).toBe(0);
    expect(res.deadTokens).toEqual([]);
  });

  test('reports permanently invalid tokens so callers can prune them', async () => {
    mockSendEach.mockResolvedValue(
      batchResult(TOKENS, [
        { index: 0, code: 'messaging/registration-token-not-registered' },
      ])
    );

    const res = await sendPush({ tokens: TOKENS, title: 't', body: 'b' });

    expect(mockSendEach).toHaveBeenCalledTimes(1); // dead codes are never retried
    expect(res.sent).toBe(2);
    expect(res.deadTokens).toEqual(['tok-1']);
  });

  test('retries the whole chunk when the multicast call itself throws', async () => {
    mockSendEach
      .mockRejectedValueOnce(new Error('ECONNRESET'))
      .mockResolvedValueOnce(batchResult(TOKENS, []));

    const pending = sendPush({ tokens: TOKENS, title: 't', body: 'b' });
    await jest.advanceTimersByTimeAsync(1000);
    const res = await pending;

    expect(mockSendEach).toHaveBeenCalledTimes(2);
    expect(res.sent).toBe(3);
  });

  test('drops unclassified errors silently without retry', async () => {
    mockSendEach.mockResolvedValue(
      batchResult(TOKENS, [{ index: 2, code: 'messaging/mismatched-credential' }])
    );

    const res = await sendPush({ tokens: TOKENS, title: 't', body: 'b' });

    expect(mockSendEach).toHaveBeenCalledTimes(1);
    expect(res.sent).toBe(2);
    expect(res.deadTokens).toEqual([]);
  });
});

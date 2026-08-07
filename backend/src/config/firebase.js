/*
- FCM push (FR-7 / Phase 5). Push is optional: the API runs without
- Firebase until FCM_SERVICE_ACCOUNT_PATH is configured, and then
- sendPush() is a no-op so the rest of the app is unaffected.
- */
let messaging = null;

try {
  const path = require('path');
  const admin = require('firebase-admin');
  // Credentials can arrive two ways: FCM_SERVICE_ACCOUNT_JSON (the raw
  // service-account JSON, the portable option for hosters like Render that
  // only accept env vars) or FCM_SERVICE_ACCOUNT_PATH (a file path, used in
  // local dev). Paths are resolved against the backend root.
  let credentials = null;
  const rawJson = process.env.FCM_SERVICE_ACCOUNT_JSON;
  const filePath = process.env.FCM_SERVICE_ACCOUNT_PATH;
  if (rawJson) {
    credentials = JSON.parse(rawJson);
  } else if (filePath) {
    credentials = require(path.resolve(__dirname, '../..', filePath));
  }
  if (credentials) {
    admin.initializeApp({ credential: admin.cert(credentials) });
    const { getMessaging } = require('firebase-admin/messaging');
    messaging = getMessaging();
    console.log('[fcm] Firebase Admin initialized');
  } else {
    console.log('[fcm] FCM_SERVICE_ACCOUNT_JSON/PATH not set; push notifications disabled');
  }
} catch (err) {
  console.error('[fcm] init failed, push disabled:', err.message);
}

// FCM error codes. Token-scoped codes are split into two buckets:
// - DEAD_TOKEN_CODES: the registration is gone forever (app uninstalled,
//   token rotated, device switched project). The token must be pruned from
//   the user's deviceTokens list so we stop paying to reach a ghost.
// - RETRYABLE_CODES: transient server/rate errors worth another attempt.
//   Anything unclassified (e.g. a credential mismatch) is dropped silently.
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-apns-credentials',
  'messaging/sender-id-mismatch',
  'messaging/mismatch-sender-id',
]);

const RETRYABLE_CODES = new Set([
  'messaging/server-unavailable',
  'messaging/internal-error',
  'messaging/third-party-auth-error',
  'messaging/unknown-error',
  'messaging/quota-exceeded',
]);

const MAX_ATTEMPTS = 3;
const RETRY_BASE_MS = 1000;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Best-effort multicast fan-out with retry. A token that still fails after
// MAX_ATTEMPTS with a retryable code is left alone (a later call may get
// through), but permanently-invalid tokens are reported back in deadTokens
// so notifyService can prune them from the owning users.
async function sendPush({ tokens, title, body, data = {} }) {
  if (!messaging || !Array.isArray(tokens) || tokens.length === 0) {
    return { sent: 0, deadTokens: [] };
  }
  const payload = {
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    android: { priority: 'high' },
  };

  let sent = 0;
  const deadTokens = [];
  let retryPool = tokens;

  for (let attempt = 0; attempt < MAX_ATTEMPTS && retryPool.length > 0; attempt += 1) {
    const nextFailures = [];
    for (let i = 0; i < retryPool.length; i += 500) {
      const chunk = retryPool.slice(i, i + 500);
      let responses;
      try {
        const result = await messaging.sendEachForMulticast({
          tokens: chunk,
          ...payload,
        });
        responses = result.responses;
        sent += result.successCount;
      } catch (err) {
        // The whole multicast threw (network/SDK failure): every token in
        // the chunk is eligible for a later attempt.
        console.warn(`[fcm] multicast attempt ${attempt + 1} failed: ${err.message}`);
        nextFailures.push(...chunk);
        continue;
      }
      responses.forEach((resp, index) => {
        const code = resp.error && resp.error.code;
        if (!code) return;
        if (DEAD_TOKEN_CODES.has(code)) deadTokens.push(chunk[index]);
        else if (RETRYABLE_CODES.has(code)) nextFailures.push(chunk[index]);
      });
    }
    retryPool = nextFailures;
    if (retryPool.length === 0) break;
    if (attempt < MAX_ATTEMPTS - 1) {
      await sleep(RETRY_BASE_MS * 2 ** attempt);
    }
  }

  if (deadTokens.length > 0) {
    console.warn(`[fcm] pruning ${deadTokens.length} stale device token(s)`);
  }
  return { sent, deadTokens };
}

module.exports = { sendPush };

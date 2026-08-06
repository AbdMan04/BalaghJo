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

async function sendPush({ tokens, title, body, data = {} }) {
  if (!messaging || !Array.isArray(tokens) || tokens.length === 0) return { sent: 0 };
  let sent = 0;
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const result = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: { priority: 'high' },
    });
    sent += result.successCount;
  }
  return { sent };
}

module.exports = { sendPush };

/*
- FCM push (FR-7 / Phase 5). Push is optional: the API runs without
- Firebase until FCM_SERVICE_ACCOUNT_PATH is configured, and then
- sendPush() is a no-op so the rest of the app is unaffected.
- */
let messaging = null;

try {
  const serviceAccountPath = process.env.FCM_SERVICE_ACCOUNT_PATH;
  if (serviceAccountPath) {
    const path = require('path');
    const admin = require('firebase-admin');
    // Resolve relative paths against the backend root so the server works
    // regardless of the directory it is started from.
    const resolved = path.resolve(__dirname, '../..', serviceAccountPath);
    admin.initializeApp({ credential: admin.cert(resolved) });
    const { getMessaging } = require('firebase-admin/messaging');
    messaging = getMessaging();
    console.log('[fcm] Firebase Admin initialized');
  } else {
    console.log('[fcm] FCM_SERVICE_ACCOUNT_PATH not set; push notifications disabled');
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

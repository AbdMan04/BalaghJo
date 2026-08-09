// BalaghJo web push service worker.
//
// Lives at the site root (/firebase-messaging-sw.js) so the Firebase JS
// SDK finds it by default when the dashboard calls getToken(). Shows a
// system notification for messages that arrive while the admin is not
// looking at the dashboard (background or closed tab). Foreground
// messages are not auto-displayed by design: the dashboard's own 30s
// polling keeps the list fresh while the site is open.
//
// Uses the Firebase compat SDK inside the worker; the app itself talks to
// firebase_messaging (FlutterFire) which is wire-compatible.
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js'
);

// Keep in sync with DefaultFirebaseOptions.web in lib/firebase_options.dart.
firebase.initializeApp({
  apiKey: 'AIzaSyDi09ZdDunH0SeTfPp8bvJ1--kedIcBYe8',
  authDomain: 'balagh-jo.firebaseapp.com',
  projectId: 'balagh-jo',
  messagingSenderId: '818549551367',
  appId: '1:818549551367:web:5b3a0a3f111c7995fa55a2',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'BALAGHJO';
  const body = notification.body || 'A new report was submitted';
  const options = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };
  return self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((list) => {
        if (list.length > 0) return list[0].focus();
        return clients.openWindow('/');
      })
  );
});

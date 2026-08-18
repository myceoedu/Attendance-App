// Kill-switch for older myRekod installs.
// Flutter used to register an offline service worker that kept stale JS/fonts
// after Vercel deploys (missing icons, old screens). New builds use
// --pwa-strategy=none and do not register a worker. Phones that already have
// the old worker re-fetch THIS file (Cache-Control: no-store), then drop it.
self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches
      .keys()
      .then(function (names) {
        return Promise.all(names.map(function (n) {
          return caches.delete(n);
        }));
      })
      .then(function () {
        return self.registration.unregister();
      })
      .then(function () {
        return self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      })
      .then(function (clients) {
        return Promise.all(
          clients.map(function (client) {
            return client.navigate(client.url);
          }),
        );
      }),
  );
});

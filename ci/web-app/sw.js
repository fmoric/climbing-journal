'use strict';

// Service worker for the installed web app (/climbing-journal/app/).
//
// Install: caches every file of this build, bypassing the browser's HTTP
// cache so a new deploy never stores stale files.
// Same-origin requests: network first (revalidated, 4 s limit), cache as
// fallback, so an online open always gets the newest version and an
// offline open still works.
// Other origins: cache first.

// Filled in at build time by prepare.py: a cache name per build and the
// list of the build's files.
const CACHE = '__CACHE__';
const PRECACHE = __PRECACHE__;
const NETWORK_TIMEOUT_MS = 4000;

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      await Promise.allSettled(
        PRECACHE.map(async (url) => {
          const res = await fetch(new Request(url, { cache: 'reload' }));
          if (res.ok) await cache.put(url, res);
        }),
      );
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
      await self.clients.claim();
    })(),
  );
});

function withTimeout(promise, ms) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(undefined), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      () => {
        clearTimeout(timer);
        resolve(undefined);
      },
    );
  });
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (!url.protocol.startsWith('http')) return;
  const sameOrigin = url.origin === self.location.origin;

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);

      if (!sameOrigin) {
        const cached = await cache.match(req);
        if (cached) return cached;
        try {
          const res = await fetch(req);
          if (res && (res.ok || res.type === 'opaque')) {
            cache.put(req, res.clone()).catch(() => undefined);
          }
          return res;
        } catch (e) {
          return Response.error();
        }
      }

      const network = fetch(new Request(req, { cache: 'no-cache' })).then((res) => {
        if (res && res.ok) cache.put(req, res.clone()).catch(() => undefined);
        return res;
      });
      const res = await withTimeout(network, NETWORK_TIMEOUT_MS);
      if (res) return res;

      const cached =
        (await cache.match(req, { ignoreSearch: true })) ||
        (req.mode === 'navigate' ? await cache.match('./') : undefined);
      if (cached) return cached;

      // Nothing cached: wait for the network after all.
      try {
        return await network;
      } catch (e) {
        return Response.error();
      }
    })(),
  );
});

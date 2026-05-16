/* Readers Retreat — Service Worker */
const CACHE = 'readers-retreat-v2';

const PRECACHE = [
  './',
  './index.html',
  './mobile.html',
  './manifest.json',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(PRECACHE))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  /* Network-first for archive.json — content updates on publish */
  if (url.pathname.endsWith('archive.json')) {
    e.respondWith(
      fetch(e.request)
        .then(res => {
          caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          return res;
        })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  /* For HTML pages ignore query params when looking up cache */
  if (url.pathname.endsWith('.html') || url.pathname.endsWith('/')) {
    const key = new Request(url.origin + url.pathname);
    e.respondWith(
      caches.match(key).then(cached => cached || fetch(e.request))
    );
    return;
  }

  /* Cache-first for everything else; populate cache on miss */
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(res => {
        if (res.ok && e.request.method === 'GET') {
          caches.open(CACHE).then(c => c.put(e.request, res.clone()));
        }
        return res;
      });
    })
  );
});

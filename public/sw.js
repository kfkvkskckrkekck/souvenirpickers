const CACHE_NAME = 'livesouvenir-v6';
const STATIC_CACHE = 'static-v6';
const DYNAMIC_CACHE = 'dynamic-v6';
const IMAGE_CACHE = 'images-v6';

const urlsToCache = [
  '/',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => cache.addAll(urlsToCache))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  console.log('[SW v6] Activating new service worker, clearing old caches');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== STATIC_CACHE &&
              cacheName !== DYNAMIC_CACHE &&
              cacheName !== IMAGE_CACHE) {
            console.log('[SW v6] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('[SW v6] Service worker activated and taking control');
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip Supabase API and function calls - let them pass through
  if (url.hostname.includes('supabase.co')) {
    console.log('[SW v6] Bypassing Supabase request:', url.href);
    return;
  }

  if (request.destination === 'image') {
    event.respondWith(cacheFirstImage(request));
  } else if (url.origin === location.origin) {
    event.respondWith(networkFirstCache(request));
  }
});

async function cacheFirstImage(request) {
  const cache = await caches.open(IMAGE_CACHE);
  const cached = await cache.match(request);

  if (cached) {
    return cached;
  }

  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    return new Response('Image not available', { status: 404 });
  }
}

async function networkFirstCache(request) {
  const cache = await caches.open(DYNAMIC_CACHE);

  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    if (cached) {
      return cached;
    }

    if (request.destination === 'document') {
      const fallback = await cache.match('/');
      if (fallback) return fallback;
    }

    return new Response('Offline - Content not available', {
      status: 503,
      statusText: 'Service Unavailable'
    });
  }
}

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  const title = data.title || 'LiveSouvenir';
  const options = {
    body: data.body || 'You have a new notification',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: data.tag || 'notification',
    data: data.url || '/',
    requireInteraction: data.requireInteraction || false,
    actions: data.actions || []
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.openWindow(event.notification.data || '/')
  );
});

self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-orders') {
    event.waitUntil(syncOrders());
  } else if (event.tag === 'sync-messages') {
    event.waitUntil(syncMessages());
  }
});

async function syncOrders() {
  console.log('Syncing orders in background...');
}

async function syncMessages() {
  console.log('Syncing messages in background...');
}

const CACHE_NAME = 'luminary-cache-v1';
const API_CACHE_NAME = 'luminary-api-cache-v1';

// URLs to cache immediately upon installation
const PRECACHE_URLS = [
    '/',
    '/main.html',
    '/profile.html',
    '/publish.html',
    '/messages.html',
    '/style.css',
    '/mobile-main.css',
    '/mobile-index.css',
    '/mobile-messages.css',
    '/luminary_logo.svg',
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css',
    'https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap'
];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(PRECACHE_URLS))
            .then(() => self.skipWaiting())
    );
});

self.addEventListener('activate', event => {
    // Clean up old caches if we bump version
    const currentCaches = [CACHE_NAME, API_CACHE_NAME];
    event.waitUntil(
        caches.keys().then(cacheNames => {
            return cacheNames.filter(cacheName => !currentCaches.includes(cacheName));
        }).then(cachesToDelete => {
            return Promise.all(cachesToDelete.map(cacheToDelete => {
                return caches.delete(cacheToDelete);
            }));
        }).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    // 1. API Requests Strategy (Network First, fallback to Cache)
    if (url.pathname.startsWith('/api/')) {
        // We only cache GET requests
        if (event.request.method !== 'GET') {
            return; // Let the browser handle POST/PUT/DELETE normally
        }

        event.respondWith(
            fetch(event.request)
                .then(networkResponse => {
                    // Update cache with fresh data
                    const responseClone = networkResponse.clone();
                    caches.open(API_CACHE_NAME).then(cache => {
                        cache.put(event.request, responseClone);
                    });
                    return networkResponse;
                })
                .catch(() => {
                    // If network fails, serve from cache
                    return caches.match(event.request);
                })
        );
        return;
    }

    // 2. Static Assets Strategy (Stale-While-Revalidate or Cache First)
    event.respondWith(
        caches.match(event.request).then(cachedResponse => {
            if (cachedResponse) {
                // Background fetch to update cache
                fetch(event.request).then(networkResponse => {
                    if (networkResponse && networkResponse.status === 200) {
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, networkResponse.clone());
                        });
                    }
                }).catch(() => { /* Ignore background fetch errors */ });

                return cachedResponse;
            }

            return fetch(event.request)
                .then(networkResponse => {
                    // Optionally cache newly visited static pages
                    if (networkResponse && networkResponse.status === 200 && networkResponse.type === 'basic') {
                        const responseClone = networkResponse.clone();
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, responseClone);
                        });
                    }
                    return networkResponse;
                });
        })
    );
});

const CACHE_NAME = 'vylithra-cache-v13';
const API_CACHE_NAME = 'vylithra-api-cache-v13';

// URLs to cache immediately upon installation
const PRECACHE_URLS = [
    '/',
    '/main',
    '/profile',
    '/messages',
    '/books',
    '/forgot-password',
    '/ui-common.css',
    '/ui-common.js',
    '/vylithra_logo.svg',
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
        if (event.request.method !== 'GET') {
            return;
        }

        event.respondWith(
            fetch(event.request)
                .then(networkResponse => {
                    if (networkResponse && networkResponse.status === 200) {
                        const responseClone = networkResponse.clone();
                        caches.open(API_CACHE_NAME).then(cache => {
                            cache.put(event.request, responseClone);
                        });
                    }
                    return networkResponse;
                })
                .catch(async () => {
                    const cachedResponse = await caches.match(event.request);
                    if (cachedResponse) return cachedResponse;
                    
                    return new Response(JSON.stringify({ msg: 'Offline mode active - Data unavailable' }), {
                        status: 503,
                        headers: { 'Content-Type': 'application/json' }
                    });
                })
        );
        return;
    }

    // 2. Navigation & HTML Requests (Network First, fallback to Cache for offline)
    if (event.request.mode === 'navigate' || (event.request.headers.get('accept') && event.request.headers.get('accept').includes('text/html'))) {
        event.respondWith(
            fetch(event.request)
                .then(networkResponse => {
                    if (networkResponse && networkResponse.status === 200) {
                        const responseClone = networkResponse.clone();
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, responseClone);
                        });
                    }
                    return networkResponse;
                })
                .catch(async () => {
                    const cachedResponse = await caches.match(event.request);
                    if (cachedResponse) return cachedResponse;
                    return caches.match('/main');
                })
        );
        return;
    }

    // 3. Static Assets Strategy (Stale-While-Revalidate)
    event.respondWith(
        caches.match(event.request).then(cachedResponse => {
            if (cachedResponse) {
                fetch(event.request).then(networkResponse => {
                    if (networkResponse && networkResponse.status === 200) {
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, networkResponse.clone());
                        });
                    }
                }).catch(() => {});

                return cachedResponse;
            }

            return fetch(event.request)
                .then(networkResponse => {
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

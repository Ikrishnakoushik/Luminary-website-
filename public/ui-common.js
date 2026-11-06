/**
 * Vylithra UI Notification System
 * Replaces native alert() and confirm()
 */

const VylithraUI = (function () {
    // Helper to ensure containers exist
    function ensureContainers() {
        if (!document.getElementById('vylithra-toast-container')) {
            const container = document.createElement('div');
            container.id = 'vylithra-toast-container';
            container.className = 'vylithra-toast-container';
            document.body.appendChild(container);
        }
    }

    return {
        showToast: function (message, type = 'success', duration = 4000) {
            ensureContainers();
            const container = document.getElementById('vylithra-toast-container');

            const toast = document.createElement('div');
            toast.className = `vylithra-toast ${type}`;

            let iconClass = 'fa-check-circle';
            if (type === 'error') iconClass = 'fa-exclamation-circle';
            if (type === 'info') iconClass = 'fa-info-circle';

            toast.innerHTML = `
                <i class="fas ${iconClass}"></i>
                <div class="toast-content">${message}</div>
            `;

            container.appendChild(toast);

            // Auto-hide
            setTimeout(() => {
                toast.classList.add('hide');
                setTimeout(() => toast.remove(), 300);
            }, duration);
        },

        showConfirm: function ({ title, message, onConfirm, onCancel, confirmText = 'Confirm', cancelText = 'Cancel' }) {
            const backdrop = document.createElement('div');
            backdrop.className = 'vylithra-modal-backdrop';

            backdrop.innerHTML = `
                <div class="vylithra-modal">
                    <div class="vylithra-modal-header">
                        <i class="fas fa-question-circle" style="color: var(--primary); font-size: 1.5rem;"></i>
                        <h3>${title || 'Confirm Action'}</h3>
                    </div>
                    <div class="vylithra-modal-body">
                        ${message || 'Are you sure you want to proceed?'}
                    </div>
                    <div class="vylithra-modal-footer">
                        <button class="vylithra-btn vylithra-btn-outline" id="vylithra-cancel-btn">${cancelText}</button>
                        <button class="vylithra-btn vylithra-btn-primary" id="vylithra-confirm-btn">${confirmText}</button>
                    </div>
                </div>
            `;

            document.body.appendChild(backdrop);

            // Show with animation
            setTimeout(() => backdrop.classList.add('show'), 10);

            const close = () => {
                backdrop.classList.remove('show');
                setTimeout(() => backdrop.remove(), 300);
            };

            backdrop.querySelector('#vylithra-confirm-btn').onclick = () => {
                if (onConfirm) onConfirm();
                close();
            };

            backdrop.querySelector('#vylithra-cancel-btn').onclick = () => {
                if (onCancel) onCancel();
                close();
            };

            // Close on backdrop click (optional)
            backdrop.onclick = (e) => {
                if (e.target === backdrop) close();
            };
        }
    };
})();

// Global Aliases (Optional, for easier migration)
window.lToast = VylithraUI.showToast;
window.lConfirm = VylithraUI.showConfirm;

// Essential Global Aliases
window.showToast = VylithraUI.showToast;
window.showConfirm = VylithraUI.showConfirm;

// Override Native Alert Site-Wide
window.alert = function (message) {
    VylithraUI.showToast(message, 'info');
};

// Register Service Worker for Offline Reading (PWA)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('ServiceWorker registration successful with scope: ', registration.scope);
            })
            .catch(err => {
                console.log('ServiceWorker registration failed: ', err);
            });
    });
}

// Global WebRTC & Firebase Integration
window.addEventListener('DOMContentLoaded', () => {
    const _t = localStorage.getItem('token');
    const _validToken = (_t && _t !== 'null' && _t !== 'undefined' && _t.trim() !== '') ? _t : null;
    if (_t && !_validToken) {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        localStorage.removeItem('role');
    }
    if (_validToken && !window.GlobalWebRTCInit) {
        window.GlobalWebRTCInit = true;
        
        // 1. Load WebRTC CSS
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = '/global-webrtc.css';
        document.head.appendChild(link);

        // 2. Load WebRTC immediately independent of Firebase
        function loadWebRTC() {
            if (!document.getElementById('global-webrtc-script')) {
                const s2 = document.createElement('script');
                s2.id = 'global-webrtc-script';
                s2.src = "/global-webrtc.js";
                document.head.appendChild(s2);
            }
        }
        loadWebRTC();

        // 3. Optional Firebase initialization in background for legacy features
        function loadFirebaseAsync() {
            const loadDb = () => {
                if (!window.firebase.database) {
                    const fbDb = document.createElement('script');
                    fbDb.src = "https://www.gstatic.com/firebasejs/10.8.0/firebase-database-compat.js";
                    fbDb.onload = initRealtime;
                    document.head.appendChild(fbDb);
                } else {
                    initRealtime();
                }
            };
            
            if (!window.firebase || !window.firebase.app) {
                const fbApp = document.createElement('script');
                fbApp.src = "https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js";
                fbApp.onload = loadDb;
                document.head.appendChild(fbApp);
            } else {
                loadDb();
            }

            function initRealtime() {
                const firebaseConfig = {
                    apiKey: "AIzaSyBMe2R5iWYj_H4IZ5OpkXSsyc9ULM5Esbw",
                    authDomain: "luminary-eae16.firebaseapp.com",
                    databaseURL: "https://luminary-eae16-default-rtdb.firebaseio.com",
                    projectId: "luminary-eae16",
                    storageBucket: "luminary-eae16.firebasestorage.app",
                    messagingSenderId: "271803460699",
                    appId: "1:271803460699:web:fcdd88f117dfe0817de37e"
                };
                if (!firebase.apps.length) {
                    firebase.initializeApp(firebaseConfig);
                }
            }
        }

        loadFirebaseAsync();
    }
});

// Production Analytics and Telemetry Interface
window.VylithraAnalytics = {
    trackEvent: function(category, action, label = '', value = 0) {
        if (window.gtag) {
            window.gtag('event', action, {
                event_category: category,
                event_label: label,
                value: value
            });
        }
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log(`[Analytics] ${category} -> ${action} (${label})`);
        }
    },
    trackPageView: function(pagePath = window.location.pathname) {
        if (window.gtag) {
            window.gtag('config', window.VYLITHRA_GA_ID || 'G-XXXXXXXXXX', {
                page_path: pagePath
            });
        }
    }
};


// Universal 5-Item Mobile Bottom Navigation Synchronizer
function setupUniversalMobileNav() {
    const p = (window.location.pathname || '').toLowerCase();
    // Exclude full-screen standalone auth/reset pages
    if (p.includes('/auth') || p.includes('/forgot-password') || p.includes('/reset-password') || p.includes('/call')) {
        return;
    }

    const navItems = [
        { name: 'Home', href: '/main', icon: 'fas fa-home', key: 'home' },
        { name: 'Trending', href: '/main?filter=trending', icon: 'fas fa-fire', key: 'trending' },
        { name: 'Reels', href: '/reels', icon: 'fas fa-play', key: 'reels' },
        { name: 'Messages', href: '/messages', icon: 'fas fa-paper-plane', key: 'messages' },
        { name: 'Profile', href: '/profile', icon: 'fas fa-user-circle', key: 'profile' }
    ];

    const search = window.location.search || '';
    let activeKey = 'home';
    if (p.includes('/reels')) activeKey = 'reels';
    else if (p.includes('/messages')) activeKey = 'messages';
    else if (p.includes('/profile')) activeKey = 'profile';
    else if (p.includes('/main') && search.includes('filter=trending')) activeKey = 'trending';
    else if (p.includes('/main') || p === '/' || p === '') activeKey = 'home';

    const existingNavs = Array.from(document.querySelectorAll('.v-mobile-nav, .mobile-bottom-nav'));
    let navContainer = existingNavs[0];

    // Remove any extra duplicate navigation elements
    for (let i = 1; i < existingNavs.length; i++) {
        existingNavs[i].remove();
    }

    if (!navContainer) {
        navContainer = document.createElement('nav');
        navContainer.className = 'v-mobile-nav';
        document.body.appendChild(navContainer);
    } else {
        navContainer.className = 'v-mobile-nav';
    }

    navContainer.innerHTML = navItems.map(item => {
        const isActive = item.key === activeKey;
        return `
            <a href="${item.href}" class="nav-item ${isActive ? 'active' : ''}">
                <i class="${item.icon}"></i>
                <span>${item.name}</span>
            </a>
        `;
    }).join('');
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupUniversalMobileNav);
} else {
    setupUniversalMobileNav();
}
window.setupUniversalMobileNav = setupUniversalMobileNav;

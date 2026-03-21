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
    if (localStorage.getItem('token') && !window.GlobalWebRTCInit) {
        window.GlobalWebRTCInit = true;
        
        // 1. Load WebRTC CSS
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = '/global-webrtc.css';
        document.head.appendChild(link);

        // 2. Ensure Firebase is loaded for Signaling
        function loadFirebaseAndWebRTC() {
            const loadDb = () => {
                if (!window.firebase.database) {
                    const fbDb = document.createElement('script');
                    fbDb.src = "https://www.gstatic.com/firebasejs/10.8.0/firebase-database-compat.js";
                    fbDb.onload = initAndLoadRealtime;
                    document.head.appendChild(fbDb);
                } else {
                    initAndLoadRealtime();
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

            function initAndLoadRealtime() {
                const firebaseConfig = {
                    apiKey: "AIzaSyBMe2R5iWYj_H4IZ5OpkXSsyc9ULM5Esbw",
                    authDomain: "luminary-eae16.firebaseapp.com",
                    projectId: "luminary-eae16",
                    storageBucket: "luminary-eae16.firebasestorage.app",
                    messagingSenderId: "271803460699",
                    appId: "1:271803460699:web:fcdd88f117dfe0817de37e"
                };
                if (!firebase.apps.length) {
                    firebase.initializeApp(firebaseConfig);
                }
                loadWebRTC();
            }
        }

        function loadWebRTC() {
            const s2 = document.createElement('script');
            s2.src = "/global-webrtc.js";
            document.head.appendChild(s2);
        }

        loadFirebaseAndWebRTC();
    }
});

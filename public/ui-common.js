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

// Override Native Alert Site-Wide
window.alert = function (message) {
    VylithraUI.showToast(message, 'info');
};

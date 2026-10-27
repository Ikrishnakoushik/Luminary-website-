(function () {
    // Vylithra Signature Cyber-Luxe Obsidian Figma Design Tokens
    const defaultTokens = {
        '--bg-color': '#07090e',
        '--surface': '#0e121b',
        '--glass-surface': 'rgba(255, 255, 255, 0.04)',
        '--glass-border': 'rgba(255, 255, 255, 0.08)',
        '--primary': '#00f2fe',
        '--accent': '#4facfe',
        '--accent-purple': '#a855f7',
        '--accent-magenta': '#ec4899',
        '--text-main': '#f8fafc',
        '--text-muted': '#94a3b8',
        '--text-light': '#64748b',
        '--border': 'rgba(255, 255, 255, 0.08)',
        '--input-bg': 'rgba(255, 255, 255, 0.05)',
        '--card-bg': 'rgba(255, 255, 255, 0.03)',
        '--card-shadow': '0 8px 32px 0 rgba(0, 0, 0, 0.45)'
    };

    const root = document.documentElement;
    root.setAttribute('data-theme', 'dark');
    if (!localStorage.getItem('theme')) {
        localStorage.setItem('theme', 'dark');
    }

    // Check if custom theme exists in localStorage
    const themeData = localStorage.getItem('spectra-theme-data');
    if (themeData) {
        try {
            const colors = JSON.parse(themeData);
            // If the user had an old light theme cached, reset to signature dark obsidian
            if (colors['--bg-color'] === '#f0fdfa' || colors['--bg-color'] === '#ffffff' || colors['--bg-color'] === '#f8fafc' || colors['--bg-color'] === '#f1f5f9') {
                localStorage.removeItem('spectra-theme-data');
            } else {
                Object.entries(colors).forEach(([key, value]) => {
                    root.style.setProperty(key, value);
                });
                return;
            }
        } catch (e) {
            console.error('Error loading theme:', e);
        }
    }

    // Apply default signature obsidian theme
    Object.entries(defaultTokens).forEach(([key, value]) => {
        root.style.setProperty(key, value);
    });

    // Ensure body also gets data-theme="dark" immediately when available
    if (document.body) {
        document.body.setAttribute('data-theme', 'dark');
    } else {
        document.addEventListener('DOMContentLoaded', () => {
            if (localStorage.getItem('theme') !== 'light') {
                document.body.setAttribute('data-theme', 'dark');
            }
        });
    }
})();

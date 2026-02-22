(function () {
    // Immediate execution to prevent flash of unstyled content
    const themeData = localStorage.getItem('luminary-theme-data');
    if (themeData) {
        try {
            const colors = JSON.parse(themeData);
            const root = document.documentElement;
            Object.entries(colors).forEach(([key, value]) => {
                root.style.setProperty(key, value);
            });
        } catch (e) {
            console.error('Error loading theme:', e);
        }
    }
})();

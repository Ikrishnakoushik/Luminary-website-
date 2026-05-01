const fs = require('fs');
let html = fs.readFileSync('public/main.html', 'utf8');

// 1. Inject CSS
const cssInjection = `
        /* === NATIVE BOTTOM NAVIGATION (OPTION 9) === */
        .mobile-bottom-nav {
            display: none;
        }

        @media (max-width: 768px) {
            .mobile-bottom-nav {
                display: flex;
                position: fixed;
                bottom: 0;
                left: 0;
                right: 0;
                height: 65px;
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(10px);
                -webkit-backdrop-filter: blur(10px);
                border-top: 1px solid rgba(0, 0, 0, 0.05);
                z-index: 1000;
                align-items: center;
                justify-content: space-around;
                padding-bottom: env(safe-area-inset-bottom);
            }

            body[data-theme='dark'] .mobile-bottom-nav {
                background: rgba(15, 23, 42, 0.95);
                border-top: 1px solid rgba(255, 255, 255, 0.05);
            }

            .bottom-nav-item {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                color: var(--text-muted);
                text-decoration: none;
                font-size: 1.4rem;
                flex: 1;
                height: 100%;
                transition: color 0.2s, transform 0.1s;
            }

            .bottom-nav-item.active {
                color: var(--primary);
            }

            .bottom-nav-item:active {
                transform: scale(0.9);
            }

            .bottom-nav-item.create-btn {
                background: linear-gradient(135deg, var(--primary), var(--secondary));
                color: white;
                height: 48px;
                width: 48px;
                flex: 0 0 48px;
                border-radius: 50%;
                box-shadow: 0 4px 15px rgba(234, 88, 12, 0.3);
                font-size: 1.2rem;
            }

            .bottom-nav-item.create-btn.active {
                color: white; /* don't change text color */
            }

            /* Adjust spacing to prevent content from hiding behind nav */
            .container {
                padding-bottom: 80px !important;
            }

            /* Hide Desktop Clutter on Mobile */
            #main-header .search-bar {
                display: none !important;
            }
            .mobile-categories {
                display: none !important;
            }
        }
`;

const styleCloseIdx = html.indexOf('</style>');
if (styleCloseIdx > -1 && !html.includes('.mobile-bottom-nav {')) {
    html = html.substring(0, styleCloseIdx) + cssInjection + html.substring(styleCloseIdx);
    console.log("Injected Mobile Bottom Nav CSS");
} else {
    console.log("CSS already injected or style block not found.");
}

// 2. Inject HTML
const htmlInjection = `
    <!-- MOBILE BOTTOM NAVIGATION (OPTION 9) -->
    <nav class="mobile-bottom-nav">
        <a href="/main" class="bottom-nav-item active">
            <i class="fas fa-home"></i>
        </a>
        <a href="/books" class="bottom-nav-item">
            <i class="fas fa-book-open"></i>
        </a>
        <a href="#" class="bottom-nav-item create-btn" onclick="handleCreatePostClick(); return false;">
            <i class="fas fa-plus"></i>
        </a>
        <a href="/reels" class="bottom-nav-item">
            <i class="fas fa-play-circle"></i>
        </a>
        <a href="/profile" class="bottom-nav-item" onclick="return enforceLogin(event)">
            <i class="fas fa-user"></i>
        </a>
    </nav>
`;

const bodyCloseIdx = html.indexOf('</body>');
if (bodyCloseIdx > -1 && !html.includes('<nav class="mobile-bottom-nav">')) {
    html = html.substring(0, bodyCloseIdx) + htmlInjection + html.substring(bodyCloseIdx);
    console.log("Injected Mobile Bottom Nav HTML");
} else {
    console.log("HTML already injected or body block not found.");
}

fs.writeFileSync('public/main.html', html);
console.log("Done");

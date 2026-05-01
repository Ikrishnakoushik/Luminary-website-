const fs = require('fs');
let html = fs.readFileSync('public/main.html', 'utf8');

const mobileCSS = `
            /* === PURE MOBILE AESTHETICS (OPTION 9) === */
            
            /* 1. Hide Desktop Clutter */
            .dashboard-layout, .dv-composer {
                display: none !important;
            }

            /* 2. Pure Backgrounds */
            body, .container, .feed {
                background: #ffffff !important;
            }
            body[data-theme='dark'], body[data-theme='dark'] .container, body[data-theme='dark'] .feed {
                background: #0f172a !important;
            }

            /* 3. Edge-to-Edge Cards */
            .post-card {
                border-radius: 0 !important;
                border-left: none !important;
                border-right: none !important;
                box-shadow: none !important;
                margin-bottom: 0 !important;
                border-bottom: 1px solid rgba(0,0,0,0.08) !important;
                padding: 18px 15px !important;
                background: transparent !important;
            }
            body[data-theme='dark'] .post-card {
                border-bottom: 1px solid rgba(255,255,255,0.08) !important;
            }

            /* 4. Minimalist Action Icons (Instagram Style) */
            .post-actions {
                border-top: none !important;
                justify-content: flex-start !important;
                gap: 20px !important;
                padding-top: 10px !important;
                margin-top: 10px !important;
            }
            
            .post-actions .action-btn {
                background: transparent !important;
                border: none !important;
                box-shadow: none !important;
                padding: 0 !important;
                color: var(--text-color) !important;
                font-size: 0.95rem !important; /* Text size */
                display: flex !important;
                align-items: center !important;
                gap: 6px !important;
            }

            .post-actions .action-btn i {
                font-size: 1.4rem !important; /* Larger icons */
            }

            /* Profile Avatars on Posts - Slightly larger for mobile */
            .post-header .avatar-sm, .post-header img.avatar-sm {
                width: 42px !important;
                height: 42px !important;
                flex: 0 0 42px !important;
            }
`;

// Insert the CSS inside the existing @media (max-width: 768px) block.
// We can find the closing brace of the bottom nav media query.
const target = '.mobile-categories {\n                display: none !important;\n            }';
if (html.includes(target)) {
    html = html.replace(target, target + '\n' + mobileCSS);
    fs.writeFileSync('public/main.html', html);
    console.log("Successfully injected mobile aesthetic CSS.");
} else {
    // fallback inject
    console.log("Target string not found. Trying fallback...");
    const regex = /@media\s*\(max-width:\s*768px\)\s*\{[\s\S]*?\}(?=\s*<\/style>)/;
    const match = html.match(regex);
    if(match) {
        const fullMatch = match[0];
        const newMatch = fullMatch.substring(0, fullMatch.lastIndexOf('}')) + mobileCSS + '\n}';
        html = html.replace(fullMatch, newMatch);
        fs.writeFileSync('public/main.html', html);
        console.log("Fallback injected.");
    } else {
        console.log("Failed to inject CSS.");
    }
}

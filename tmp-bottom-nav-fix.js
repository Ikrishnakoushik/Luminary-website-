const fs = require('fs');

let html = fs.readFileSync('public/main.html', 'utf8');

// 1. Replace HTML
const htmlRegex = /<!-- MOBILE BOTTOM NAVIGATION \(OPTION 9\) -->[\s\S]*?<\/nav>/;
const newHtml = `<!-- MOBILE BOTTOM NAVIGATION (OPTION 9 EXACT MATCH) -->
    <nav class="mobile-bottom-nav">
        <a href="/main" class="bottom-nav-item active">
            <i class="fas fa-home"></i>
        </a>
        <a href="/reels" class="bottom-nav-item">
            <i class="fas fa-play"></i>
        </a>
        <a href="/messages" class="bottom-nav-item">
            <i class="fas fa-paper-plane"></i>
        </a>
        <a href="/profile" class="bottom-nav-item" onclick="return enforceLogin(event)">
            <i class="fas fa-user-circle"></i>
        </a>
    </nav>`;

if(html.match(htmlRegex)) {
    html = html.replace(htmlRegex, newHtml);
    console.log("HTML Replaced");
} else {
    // If not found, maybe I should append before </body>
    const bodyClose = html.indexOf('</body>');
    html = html.substring(0, bodyClose) + newHtml + '\n' + html.substring(bodyClose);
    console.log("HTML Appended");
}

// 2. Replace CSS
const cssRegex = /\/\* === NATIVE BOTTOM NAVIGATION \(OPTION 9\) === \*\/[\s\S]*?(?=\/\* Adjust spacing)/;
const newCss = `/* === NATIVE BOTTOM NAVIGATION (OPTION 9 EXACT MATCH) === */
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
                height: 60px;
                background: linear-gradient(180deg, rgba(255, 255, 255, 0.8) 0%, rgba(226, 238, 255, 0.95) 100%);
                backdrop-filter: blur(15px);
                -webkit-backdrop-filter: blur(15px);
                border-top: 1px solid rgba(255, 255, 255, 0.8);
                z-index: 1000;
                align-items: center;
                justify-content: space-evenly;
                padding-bottom: env(safe-area-inset-bottom);
                box-shadow: 0 -4px 20px rgba(0,0,0,0.03);
            }

            body[data-theme='dark'] .mobile-bottom-nav {
                background: linear-gradient(180deg, rgba(15, 23, 42, 0.8) 0%, rgba(10, 15, 30, 0.95) 100%);
                border-top: 1px solid rgba(255, 255, 255, 0.05);
            }

            .bottom-nav-item {
                display: flex;
                align-items: center;
                justify-content: center;
                color: #a0a8b9; /* The solid grey from the photo */
                text-decoration: none;
                font-size: 1.65rem;
                flex: 1;
                height: 100%;
                transition: color 0.2s, transform 0.1s;
            }

            .bottom-nav-item.active {
                color: #4a5568; /* Darker grey for active */
            }
            body[data-theme='dark'] .bottom-nav-item.active {
                color: #ffffff;
            }

            .bottom-nav-item:active {
                transform: scale(0.9);
            }

            `;

if(html.match(cssRegex)) {
    html = html.replace(cssRegex, newCss);
    console.log("CSS Replaced");
} else {
    console.log("CSS regex not found, skipping or needs manual inject.");
}

// Ensure the old create-btn CSS is removed if it wasn't caught
html = html.replace(/\.bottom-nav-item\.create-btn[\s\S]*?\}/g, '');
html = html.replace(/\.bottom-nav-item\.create-btn\.active[\s\S]*?\}/g, '');

fs.writeFileSync('public/main.html', html);
console.log("File saved.");

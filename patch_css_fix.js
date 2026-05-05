const fs = require('fs');
let html = fs.readFileSync('public/profile.html', 'utf8');

// 1. Remove the @media max-width wrapper
html = html.replace(/@media\s*\(\s*max-width:\s*768px\s*\)\s*\{\s*\/\*\s*---\s*NEUMORPHISM BASE\s*---\s*\*\//, '/* --- NEUMORPHISM BASE --- */');

// 2. Add max-width to .unified-container
html = html.replace(/\.unified-container\s*\{[\s\S]*?padding:\s*20px;[\s\S]*?margin-top:\s*0;[\s\S]*?background:\s*transparent;[\s\S]*?\}/, `.unified-container {
            padding: 20px;
            margin-top: 60px; /* offset for hero cover */
            background: transparent;
            max-width: 800px;
            margin: 60px auto 0 auto;
            position: relative;
            z-index: 10;
        }`);

// 3. Remove the trailing closing brace
html = html.replace(/body\[data-theme='dark'\]\s*\.profile-footer-row\s*\{\s*box-shadow:[^}]*\}\s*\}/, `body[data-theme='dark'] .profile-footer-row {
            box-shadow: inset 0px 4px 6px -6px #0f172a !important;
        }`);

fs.writeFileSync('public/profile.html', html);
console.log('Regex patch complete');

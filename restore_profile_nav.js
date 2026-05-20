const fs = require('fs');
let html = fs.readFileSync('public/main.html', 'utf8');

html = html.replace(
    /onclick="\$\{hasActiveStory \? `openStoryViewer\('\$\{post\.user\._id\}'\)` : `window\.location\.href='\/profile\.html\?user=\$\{post\.user\._id\}'`\}"/g,
    'onclick="window.location.href=\\'/profile.html?user=${post.user._id}\\'"'
);

fs.writeFileSync('public/main.html', html);
console.log('Restored profile page navigation for post headers.');

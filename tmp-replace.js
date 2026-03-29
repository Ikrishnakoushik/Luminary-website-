const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, 'public');

const target1 = '<a href="community" class="nav-item">\n                <i class="fa-solid fa-users"></i> Community\n            </a>';
const target2 = '<a href="community" class="nav-item">\r\n                <i class="fa-solid fa-users"></i> Community\r\n            </a>';
const replacement1 = target1 + '\n            <a href="reels.html" class="nav-item">\n                <i class="fas fa-play-circle"></i> Reels\n            </a>';
const replacement2 = target2 + '\r\n            <a href="reels.html" class="nav-item">\r\n                <i class="fas fa-play-circle"></i> Reels\r\n            </a>';

fs.readdirSync(dir).filter(f => f.endsWith('.html')).forEach(file => {
    const filePath = path.join(dir, file);
    let content = fs.readFileSync(filePath, 'utf8');
    let mod = false;
    
    if (content.includes(target1)) {
        content = content.replace(target1, replacement1);
        mod = true;
    } else if (content.includes(target2)) {
        content = content.replace(target2, replacement2);
        mod = true;
    }

    if (mod) {
        fs.writeFileSync(filePath, content);
        console.log('Successfully injected Reels navigation into: ' + file);
    }
});

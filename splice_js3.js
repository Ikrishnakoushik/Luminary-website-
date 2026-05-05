const fs = require('fs');
let lines = fs.readFileSync('public/profile.html', 'utf8').split('\n');

const newJs = `                    // Bind stat clicks
                    const fBtn = document.getElementById('followers-stat-btn');
                    const followingBtn = document.getElementById('following-stat-btn');
                    if (fBtn) fBtn.onclick = () => openFollowModal('followers', user._id || myId);
                    if (followingBtn) followingBtn.onclick = () => openFollowModal('following', user._id || myId);`;

lines.splice(680, 0, newJs); // Insert near the end of renderProfile
fs.writeFileSync('public/profile.html', lines.join('\n'));

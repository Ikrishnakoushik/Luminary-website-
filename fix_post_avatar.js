const fs = require('fs');

let html = fs.readFileSync('public/main.html', 'utf8');

// The new logic to inject right before `const postAvatar = ...`
const ringLogic = `
                    // Post Avatar logic
                    const currentUserId = localStorage.getItem('user') ? JSON.parse(localStorage.getItem('user'))._id : null;
                    const userStoryGroup = typeof globalStories !== 'undefined' ? globalStories.find(g => g.user && g.user._id === authorId) : null;
                    const hasActiveStory = userStoryGroup && !userStoryGroup.stories.every(s => currentUserId && s.viewers.includes(currentUserId));
                    const avatarClass = hasActiveStory ? "avatar-sm story-ring" : "avatar-sm";
                    
                    const postAvatar = post.user?.profilePicture
                        ? \`<img src="\${(post.user.profilePicture) && String(post.user.profilePicture).startsWith('http') ? (post.user.profilePicture) : '/' + (post.user.profilePicture)}" class="\${avatarClass}" style="object-fit: cover; cursor:pointer;" \${hasActiveStory ? \`onclick="event.preventDefault(); openStoryViewer('\${authorId}')"\` : ''}>\`
                        : \`<div class="\${avatarClass}" style="cursor:pointer;" \${hasActiveStory ? \`onclick="event.preventDefault(); openStoryViewer('\${authorId}')"\` : ''}>\${initial}</div>\`;
`;

// Replace the old postAvatar declaration
html = html.replace(/[\s\S]*?\/\/ Post Avatar logic[\s\S]*?const postAvatar[\s\S]*?<\/div>\`;/, function(match) {
    if (match.includes('hasActiveStory')) return match; // Already injected
    
    return match.replace(/\/\/ Post Avatar logic[\s\S]*?<\/div>\`;/, ringLogic.trim());
});

fs.writeFileSync('public/main.html', html);
console.log('Post Avatar logic updated.');

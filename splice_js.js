const fs = require('fs');
let lines = fs.readFileSync('public/profile.html', 'utf8').split('\n');

const newJs = `                    // Update Action Buttons Visibility
                    const editBtn = document.getElementById('edit-profile-btn');
                    const followBtn = document.getElementById('follow-profile-btn');
                    const msgBtn = document.getElementById('message-profile-btn');
                    const shareBtn = document.getElementById('profile-share-btn');
                    
                    if (user.isMe) {
                        if (editBtn) editBtn.style.display = 'flex';
                        if (followBtn) followBtn.style.display = 'none';
                        if (msgBtn) msgBtn.style.display = 'none';
                    } else {
                        if (editBtn) editBtn.style.display = 'none';
                        if (followBtn) followBtn.style.display = 'flex';
                        if (msgBtn) msgBtn.style.display = 'flex';
                        
                        // Set up Message routing
                        if (msgBtn) {
                            msgBtn.onclick = () => {
                                window.location.href = 'messages.html?user=' + user._id;
                            };
                        }
                        
                        // Set up Follow state logic
                        window.currentProfileId = user._id;
                        window.isConnected = false;
                        
                        const loadConnectionState = async () => {
                            const token = localStorage.getItem('token');
                            if (!token) return;
                            try {
                                const res = await fetch(\`\${API_URL}/users/me/following\`, { headers: { 'x-auth-token': token } });
                                if (res.ok) {
                                    const following = await res.json();
                                    window.isConnected = following.some(c => c._id === user._id);
                                    updateFollowUI();
                                }
                            } catch (e) { console.error(e); }
                        };
                        
                        loadConnectionState();
                    }
                    
                    if (shareBtn) {
                        shareBtn.onclick = () => {
                            const url = window.location.href.split('?')[0] + '?user=' + (user._id || '');
                            navigator.clipboard.writeText(url).then(() => {
                                VylithraUI.showToast('Profile link copied to clipboard!', 'success');
                            });
                        };
                    }`;

lines.splice(640, 153, newJs);
fs.writeFileSync('public/profile.html', lines.join('\n'));

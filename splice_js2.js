const fs = require('fs');
let lines = fs.readFileSync('public/profile.html', 'utf8').split('\n');

const newFunctions = `
                function updateFollowUI() {
                    const btn = document.getElementById('follow-profile-btn');
                    if (!btn) return;
                    if (window.isConnected) {
                        btn.innerHTML = '<i class="fas fa-user-check"></i> Following';
                        btn.style.background = '#10b981';
                        btn.style.color = '#fff';
                        btn.style.border = 'none';
                    } else {
                        btn.innerHTML = '<i class="fas fa-user-plus"></i> Follow';
                        btn.style.background = 'var(--surface)';
                        btn.style.color = 'var(--text)';
                        btn.style.border = '1px solid var(--border)';
                    }
                }

                async function toggleFollow() {
                    const token = localStorage.getItem('token');
                    if (!token) {
                        VylithraUI.showToast('Please login to follow users!', 'error');
                        setTimeout(() => window.location.href = 'auth', 1500);
                        return;
                    }

                    const btn = document.getElementById('follow-profile-btn');
                    if (btn.disabled) return;
                    btn.disabled = true;

                    const method = window.isConnected ? 'DELETE' : 'POST';
                    const url = window.isConnected ? \`\${API_URL}/users/\${window.currentProfileId}/unfollow\` : \`\${API_URL}/users/\${window.currentProfileId}/follow\`;

                    // Optimistic update
                    window.isConnected = !window.isConnected;
                    updateFollowUI();

                    try {
                        const res = await fetch(url, {
                            method: method,
                            headers: { 'x-auth-token': token }
                        });

                        if (!res.ok) throw new Error('Action failed');

                        // Update stats
                        const fCountEl = document.getElementById('profile-followers-count');
                        if (fCountEl) {
                            let c = parseInt(fCountEl.innerText) || 0;
                            fCountEl.innerText = window.isConnected ? c + 1 : Math.max(0, c - 1);
                        }
                    } catch (e) {
                        window.isConnected = !window.isConnected;
                        updateFollowUI();
                        VylithraUI.showToast('Error following user', 'error');
                    } finally {
                        btn.disabled = false;
                    }
                }

                function closeFollowModal() {
                    document.getElementById('followListModal').style.display = 'none';
                }
`;

lines.splice(1630, 0, newFunctions); // Insert right before openFollowModal
fs.writeFileSync('public/profile.html', lines.join('\n'));

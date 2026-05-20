const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'public', 'profile.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Replace CSS
const cssStart = content.indexOf('<style>');
const cssEnd = content.indexOf('</style>') + 8;
const newCss = `<style>
        /* --- CSS VARIABLES --- */
        :root {
            --bg-color: #f8f6eb; 
            --surface: #ffffff; 
            --primary: #4a3b31;
            --primary-hover: #3e2723;
            --text-main: #3e2723;
            --text-muted: #5d4037;
            --border: #dcd4c6;
            --input-bg: #fff;
            --accent: #4a3b31;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Playfair Display', serif;
            background-color: var(--bg-color) !important;
            color: var(--text-main);
            line-height: 1.6;
            -webkit-font-smoothing: antialiased;
            padding-bottom: 50px;
            overflow-x: hidden;
        }

        /* Top Nav */
        .vintage-nav {
            display: flex; justify-content: space-between; align-items: center;
            padding: 20px; font-family: 'Inter', sans-serif;
            font-size: 1.2rem; color: var(--text-main); font-weight: 600;
        }
        .vintage-nav a { color: var(--text-main); text-decoration: none; font-size: 1.5rem; }
        .vintage-nav .nav-handle { font-size: 1.2rem; }

        .unified-container { max-width: 600px; margin: 0 auto; padding: 0 15px; }
        
        .profile-header-top-row { display: flex; flex-direction: column; align-items: center; text-align: center; margin-top: 10px; }
        
        /* Avatar */
        .profile-avatar-wrapper { position: relative; display: inline-block; }
        .profile-avatar-large {
            width: 140px; height: 140px; border-radius: 50%;
            border: 3px solid #8e6a4b;
            padding: 6px;
            background-clip: content-box;
            background-color: #8e6a4b;
            color: #fff; display: flex; align-items: center; justify-content: center;
            font-size: 40px; font-weight: 800; font-family: 'Inter', sans-serif;
        }
        
        /* Buttons */
        .profile-actions { display: flex; justify-content: center; align-items: center; gap: 15px; margin: 15px 0 20px 0; }
        .btn-follow {
            background: #4a3b31; color: #fff; border: none; border-radius: 6px;
            padding: 10px 24px; font-weight: 600; font-family: 'Inter', sans-serif;
            font-size: 0.9rem; letter-spacing: 1px; cursor: pointer; text-transform: uppercase;
        }
        .btn-message {
            background: transparent; color: #4a3b31; border: 2px solid #4a3b31;
            border-radius: 6px; padding: 8px 24px; font-weight: 600; font-family: 'Inter', sans-serif;
            font-size: 0.9rem; letter-spacing: 1px; cursor: pointer; text-transform: uppercase;
        }

        /* Name & Bio */
        .profile-name-title { font-size: 2.4rem; font-weight: 700; margin: 10px 0 0 0; }
        .profile-handle-text { font-family: 'Inter', sans-serif; font-size: 1.1rem; color: var(--text-muted); font-style: italic; margin-bottom: 5px; }
        .profile-bio-text { font-size: 1.1rem; margin: 15px 20px; line-height: 1.4; color: var(--text-main); }

        /* Stats */
        .profile-stats-group {
            display: flex; justify-content: center; align-items: center;
            margin: 20px 0 30px 0; width: 100%; padding-top: 10px;
        }
        .stat-item { flex: 1; text-align: center; border-right: 1px solid var(--border); }
        .stat-item:last-child { border-right: none; }
        .stat-val { font-size: 1.8rem; font-weight: 700; display: block; line-height: 1; margin-bottom: 4px; }
        .stat-label { font-size: 1rem; color: var(--text-main); font-family: 'Inter', sans-serif; }

        /* Tabs */
        .profile-tabs {
            display: flex; justify-content: space-around; width: 100%;
            border-bottom: 2px solid var(--border); margin-bottom: 20px;
        }
        .profile-tab {
            font-family: 'Inter', sans-serif; font-weight: 700; font-size: 1.1rem;
            color: var(--text-muted); padding: 10px 0; cursor: pointer; width: 50%; text-align: center; text-transform: uppercase;
        }
        .profile-tab.active { color: var(--primary); border-bottom: 4px solid var(--primary); margin-bottom: -2px; }

        /* Polaroid Grid */
        .posts-grid-container {
            display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin-bottom: 40px; padding: 0 10px;
        }
        @media (max-width: 480px) {
            .posts-grid-container { gap: 10px; }
            .profile-avatar-large { width: 100px; height: 100px; padding: 4px; border-width: 2px; }
            .btn-follow, .btn-message { padding: 8px 16px; font-size: 0.8rem; }
        }
        .post-card.compact {
            background: #fff; padding: 8px 8px 24px 8px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.08);
            cursor: pointer; position: relative; border-radius: 2px;
            transition: transform 0.2s; border: none; display: flex; flex-direction: column;
        }
        .post-card.compact:hover { transform: translateY(-3px) rotate(1deg); box-shadow: 0 6px 15px rgba(0,0,0,0.12); }
        
        .compact-img-container {
            width: 100%; aspect-ratio: 1 / 1; position: relative; background: #e0e0e0; overflow: hidden;
        }
        .compact-img { width: 100%; height: 100%; object-fit: cover; }
        
        /* Photo Corners */
        .photo-corner { position: absolute; width: 14px; height: 14px; background: #2a2018; z-index: 2; }
        .corner-tl { top: 0; left: 0; clip-path: polygon(0 0, 100% 0, 0 100%); }
        .corner-tr { top: 0; right: 0; clip-path: polygon(0 0, 100% 0, 100% 100%); }
        .corner-bl { bottom: 0; left: 0; clip-path: polygon(0 0, 100% 100%, 0 100%); }
        .corner-br { bottom: 0; right: 0; clip-path: polygon(100% 0, 100% 100%, 0 100%); }

        .compact-body { display: none; } /* Hide the text info for polaroid look */
        
        /* General hidden items */
        .hero-cover, .profile-banner, .newsletter, #projects-section, #interests-section, .section-header { display: none !important; }
        .social-links { display: none !important; }
        body[data-theme='dark'] { background-color: var(--bg-color) !important; color: var(--text-main) !important; } /* Override dark mode for this page */

        /* Modals and Overlays */
        .modal { display: none; position: fixed; z-index: 2000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(62, 39, 35, 0.6); align-items: center; justify-content: center; }
        .modal-content { background: var(--bg-color); padding: 30px; border-radius: 8px; width: 90%; max-width: 400px; position: relative; border: 1px solid var(--border); }
        .close { position: absolute; right: 20px; top: 20px; font-size: 24px; cursor: pointer; color: var(--text-muted); }
        .form-group { margin-bottom: 20px; text-align: left; font-family: 'Inter', sans-serif; }
        .form-group label { display: block; margin-bottom: 8px; font-weight: 500; }
        .form-group input, .form-group select { width: 100%; padding: 12px; border: 1px solid var(--border); border-radius: 4px; background: #fff; }
        .form-btn { width: 100%; padding: 12px; border: none; border-radius: 4px; background: var(--primary); color: white; font-weight: 600; cursor: pointer; }
        
        #oauthOverlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(62, 39, 35, 0.8); z-index: 9998; }
        #oauthPopup { display: none; position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: var(--bg-color); padding: 40px; border-radius: 8px; text-align: center; z-index: 9999; width: 90%; max-width: 400px; }
        .oauth-loader { border: 4px solid var(--border); border-top: 4px solid var(--primary); border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 20px auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

        /* Reader Overlay */
        .reader-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: var(--bg-color); z-index: 3000; overflow-y: auto; padding: 40px 20px; }
        .reader-content { max-width: 800px; margin: 0 auto; background: #fff; padding: 40px; border-radius: 4px; box-shadow: 0 10px 30px rgba(0,0,0,0.1); position: relative; }
        .reader-close { position: absolute; top: 20px; right: 20px; background: transparent; border: none; font-size: 24px; color: var(--text-muted); cursor: pointer; }
        .reader-title { font-size: 36px; color: var(--text-main); margin-bottom: 10px; }
        .reader-meta { color: var(--text-muted); font-family: 'Inter', sans-serif; font-size: 14px; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 1px solid var(--border); }
</style>`;

content = content.substring(0, cssStart) + newCss + content.substring(cssEnd);

// 2. Replace Header HTML
const navStart = content.indexOf('<!-- PREMIUM TOP NAVIGATION -->');
const mainStart = content.indexOf('<main class="feed"');
const newHeader = `<!-- PREMIUM TOP NAVIGATION -->
    <nav class="vintage-nav">
        <a href="main"><i class="fas fa-chevron-left"></i></a>
        <span class="nav-handle" id="top-nav-handle">@username</span>
        <a href="#"><i class="fas fa-bars"></i></a>
    </nav>
    
    <div class="unified-container">
        
        <div class="profile-header-top-row fade-in">
            <div style="display: flex; align-items: center; justify-content: center; gap: 20px; margin-bottom: 15px; width: 100%;">
                <button class="btn-follow" id="follow-profile-btn" onclick="toggleFollow()" style="display:none;">FOLLOW</button>
                <div class="profile-avatar-wrapper">
                    <div class="profile-avatar-large" id="profile-avatar"></div>
                </div>
                <button class="btn-message" id="message-profile-btn" onclick="messageUser()" style="display:none;">MESSAGE</button>
                <!-- Edit Profile Button (for owner) -->
                <button class="btn-message" id="edit-profile-btn" style="display:none;" onclick="openSettings()">EDIT</button>
            </div>
            
            <h1 class="profile-name-title" id="profile-name">Sarah J. Woods</h1>
            <div class="profile-handle-text" id="profile-handle">@sarah_woods</div>
            
            <p class="profile-bio-text" id="profile-bio">Nostalgic soul, capturing fleeting moments in celluloid & light. 🌿✨</p>
            
            <div class="profile-stats-group" id="profile-stats">
                <div class="stat-item" id="spreads-stat-btn">
                    <span class="stat-val" id="profile-spreads-count">0</span>
                    <span class="stat-label">Posts</span>
                </div>
                <div class="stat-item" id="followers-stat-btn">
                    <span class="stat-val" id="profile-followers-count">0</span>
                    <span class="stat-label">Followers</span>
                </div>
                <div class="stat-item" id="following-stat-btn">
                    <span class="stat-val" id="profile-following-count">0</span>
                    <span class="stat-label">Following</span>
                </div>
            </div>
            
            <div class="profile-tabs">
                <div class="profile-tab active">PHOTOS</div>
                <div class="profile-tab">TAGGED</div>
            </div>
        </div>

        <!-- RIGHT CONTENT (NOW BOTTOM CONTENT) -->
        `;

content = content.substring(0, navStart) + newHeader + content.substring(mainStart);

// 3. Fix JS to not append "Joined Date" to handle, and update top nav handle
content = content.replace(
    /document\.getElementById\('profile-handle'\)\.innerHTML = '@' \+ \(user\.username \|\| 'user'\)\.toLowerCase\(\)\.replace\(\/\\s\/g, ''\) \+ ' &middot; Joined ' \+ joinDate;/g,
    `const cleanHandle = '@' + (user.username || 'user').toLowerCase().replace(/\\s/g, '');
    document.getElementById('profile-handle').innerText = cleanHandle;
    document.getElementById('top-nav-handle').innerText = cleanHandle;`
);

// 4. Update renderPosts Grid Card HTML
content = content.replace(/if \(layout === 'grid'\) \{[\s\S]*?\} else \{/, `if (layout === 'grid') {
                    // GRID CARD HTML
                    const card = document.createElement('article');
                    card.className = 'post-card compact';
                    card.onclick = () => openReaderFromId(post._id, safeTitle, safeAuthor, safeTime);
                    card.style.cursor = 'pointer';

                    let imageHtml = '';
                    if (post.image) {
                        imageHtml = \`<img src="\${(post.image) && String(post.image).startsWith('http') ? (post.image) : '/' + (post.image)}" class="compact-img" alt="\${safeTitle}">\`;
                    } else {
                        // Placeholder
                        imageHtml = \`<div class="compact-img" style="background: #e0e0e0; color: #4a3b31; display: flex; align-items: center; justify-content: center; font-size: 2rem; font-family: 'Inter', sans-serif;">\${initial}</div>\`;
                    }

                    card.innerHTML = \`
                        <div class="compact-img-container">
                            <div class="photo-corner corner-tl"></div>
                            <div class="photo-corner corner-tr"></div>
                            <div class="photo-corner corner-bl"></div>
                            <div class="photo-corner corner-br"></div>
                            \${imageHtml}
                        </div>
                        <div class="compact-body"></div>
                        <!-- Hidden content store for Reader -->
                        <div id="content-store-\${post._id}" style="display:none;">\${fullContent}</div>
                    \`;
                    container.appendChild(card);

                } else {`);


// Fix default avatars
content = content.replace(/background: 'linear-gradient\\(135deg, #667eea 0%, #764ba2 100%\\)'/g, "background: 'var(--primary)'");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Successfully patched profile.html');

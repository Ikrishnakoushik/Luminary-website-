const fs = require('fs');

function injectStories() {
    let html = fs.readFileSync('public/main.html', 'utf8');

    const cssBlock = `
        /* === STORIES VIEWER === */
        .story-ring {
            border: 3px solid transparent;
            background-image: linear-gradient(var(--bg-color), var(--bg-color)), linear-gradient(45deg, #f09433 0%, #e6683c 25%, #dc2743 50%, #cc2366 75%, #bc1888 100%);
            background-origin: border-box;
            background-clip: content-box, border-box;
            padding: 2px;
            border-radius: 50%;
            cursor: pointer;
        }
        .story-viewer-overlay {
            position: fixed; inset: 0; background: #000; z-index: 9999; display: none; flex-direction: column; color: #fff;
        }
        .story-viewer-overlay.active { display: flex; }
        .story-progress-container { display: flex; gap: 4px; padding: 10px; position: absolute; top: 0; left: 0; right: 0; z-index: 10; }
        .story-progress-bar { flex: 1; height: 3px; background: rgba(255,255,255,0.3); border-radius: 2px; overflow: hidden; }
        .story-progress-fill { height: 100%; width: 0%; background: #fff; }
        .story-header { position: absolute; top: 25px; left: 0; right: 0; display: flex; align-items: center; padding: 10px 15px; z-index: 10; }
        .story-viewer-avatar { width: 32px; height: 32px; border-radius: 50%; margin-right: 10px; object-fit: cover; }
        .story-viewer-name { font-weight: 600; text-shadow: 0 1px 3px rgba(0,0,0,0.8); flex: 1; }
        .story-close-btn { background: none; border: none; color: #fff; font-size: 24px; cursor: pointer; text-shadow: 0 1px 3px rgba(0,0,0,0.8); }
        .story-media-container { flex: 1; display: flex; align-items: center; justify-content: center; position: relative; background: #111; }
        .story-media-container img, .story-media-container video { max-width: 100%; max-height: 100vh; object-fit: contain; }
        .story-nav-left, .story-nav-right { position: absolute; top: 50px; bottom: 0; width: 30%; z-index: 5; cursor: pointer; }
        .story-nav-left { left: 0; }
        .story-nav-right { right: 0; }
        .uploading-story-indicator { position: absolute; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; color: white; border-radius: 50%; z-index: 10; }
    `;

    if (!html.includes('.story-viewer-overlay {')) {
        html = html.replace('</style>', cssBlock + '\n    </style>');
    }

    const htmlBlock = `
    <input type="file" id="storyUploadInput" accept="image/*,video/*" style="display:none;" onchange="handleStoryUpload(event)">
    <div id="storyViewerOverlay" class="story-viewer-overlay">
       <div class="story-progress-container" id="storyProgressContainer"></div>
       <div class="story-header">
           <img id="storyViewerAvatar" class="story-viewer-avatar" src="" alt="avatar">
           <span id="storyViewerName" class="story-viewer-name"></span>
           <button class="story-close-btn" onclick="closeStoryViewer()"><i class="fas fa-times"></i></button>
       </div>
       <div class="story-media-container">
           <img id="storyViewerImage" style="display:none;" />
           <video id="storyViewerVideo" style="display:none;" autoplay playsinline></video>
       </div>
       <div class="story-nav-left" onclick="prevStory()"></div>
       <div class="story-nav-right" onclick="nextStory()"></div>
    </div>
    `;

    if (!html.includes('id="storyViewerOverlay"')) {
        html = html.replace('<body>', '<body>\n' + htmlBlock);
    }

    const jsCode = fs.readFileSync('new_stories_logic.js', 'utf8');

    const oldRenderStart = html.indexOf('async function renderStories() {');
    const oldRenderEnd = html.indexOf('// === END MOBILE STORIES RAIL LOGIC ===');

    if (oldRenderStart !== -1 && oldRenderEnd !== -1 && !html.includes('globalStories = await res.json();')) {
        html = html.substring(0, oldRenderStart) + jsCode + html.substring(oldRenderEnd + '// === END MOBILE STORIES RAIL LOGIC ==='.length);
    }

    // Replace renderPost Logic for rings
    // We will do a generic replace in renderPosts
    // Find where avatar is rendered in fetchPosts/renderPost
    let renderPostFnStart = html.indexOf('htmlContent += `');
    if(renderPostFnStart !== -1 && html.includes("globalStories") && !html.includes('avatarClass')) {
        // This is a bit too risky to regex directly without seeing the code. Let's just do it manually.
    }

    fs.writeFileSync('public/main.html', html);
    console.log('Injected successfully');
}

injectStories();

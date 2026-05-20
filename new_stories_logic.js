// === INSTAGRAM STORIES LOGIC ===
        let globalStories = [];
        let currentStoryUserIndex = 0;
        let currentStoryIndex = 0;
        let storyTimeout = null;

        async function renderStories() {
            const rail = document.getElementById('stories-rail');
            if(!rail) return;
            
            let htmlContent = `
                <div class="story-item" onclick="document.getElementById('storyUploadInput').click()">
                    <div class="story-avatar-wrapper add-story" style="position:relative;">
                        <div class="story-avatar" style="color: #64748b; background: transparent; border: none;">
                            <i class="fas fa-plus"></i>
                        </div>
                        <div id="storyUploadSpinner" class="uploading-story-indicator" style="display:none;">
                            <i class="fas fa-spinner fa-spin"></i>
                        </div>
                    </div>
                    <div class="story-username">Your Story</div>
                </div>
            `;
            
            try {
                const res = await fetch('/api/stories/feed', { headers: { 'x-auth-token': localStorage.getItem('token') } });
                if (res.ok) {
                    globalStories = await res.json();
                    
                    globalStories.forEach((userGroup, idx) => {
                        const u = userGroup.user;
                        if (!u) return;
                        const initial = u.name ? u.name.charAt(0).toUpperCase() : u.username.charAt(0).toUpperCase();
                        const color = `hsl(${(u.username.charCodeAt(0) * 20) % 360}, 70%, 50%)`;
                        
                        const currentUserId = localStorage.getItem('user') ? JSON.parse(localStorage.getItem('user'))._id : null;
                        const allViewed = userGroup.stories.every(s => currentUserId && s.viewers.includes(currentUserId));
                        const ringClass = allViewed ? '' : 'story-ring';
                        
                        htmlContent += `
                            <div class="story-item" onclick="openStoryViewer('${u._id}')">
                                <div class="story-avatar-wrapper ${ringClass}">
                                    ${u.profilePicture 
                                        ? `<img src="${u.profilePicture}" class="story-avatar" style="object-fit:cover;">`
                                        : `<div class="story-avatar" style="background-color: ${color};">${initial}</div>`
                                    }
                                </div>
                                <div class="story-username">${u.name || u.username}</div>
                            </div>
                        `;
                    });
                }
                rail.innerHTML = htmlContent;
                // We will manually trigger a re-render of posts here if needed
            } catch (e) {
                console.error('Error fetching stories:', e);
                rail.innerHTML = htmlContent;
            }
        }

        async function handleStoryUpload(e) {
            const file = e.target.files[0];
            if (!file) return;
            
            document.getElementById('storyUploadSpinner').style.display = 'flex';
            
            const formData = new FormData();
            formData.append('storyMedia', file);
            
            try {
                const res = await fetch('/api/stories/upload', {
                    method: 'POST',
                    headers: { 'x-auth-token': localStorage.getItem('token') },
                    body: formData
                });
                
                if (res.ok) {
                    renderStories();
                } else {
                    const data = await res.json();
                    alert(data.msg || 'Failed to upload story');
                }
            } catch (err) {
                alert('Network error uploading story');
            } finally {
                document.getElementById('storyUploadSpinner').style.display = 'none';
                e.target.value = '';
            }
        }
        
        function openStoryViewer(userId) {
            const userIndex = globalStories.findIndex(g => g.user._id === userId);
            if (userIndex === -1) {
                fetch(`/api/stories/user/${userId}`, { headers: { 'x-auth-token': localStorage.getItem('token') } })
                    .then(res => res.json())
                    .then(stories => {
                        if (stories.length) playStandaloneStory(stories);
                        else window.location.href = `/profile.html?user=${userId}`;
                    });
                return;
            }
            currentStoryUserIndex = userIndex;
            currentStoryIndex = 0;
            document.getElementById('storyViewerOverlay').classList.add('active');
            playCurrentStory();
        }
        
        let standaloneMode = false;
        let standaloneStories = [];
        
        function playStandaloneStory(stories) {
            standaloneMode = true;
            standaloneStories = stories;
            currentStoryIndex = 0;
            document.getElementById('storyViewerOverlay').classList.add('active');
            playStoryInternal(stories, stories[0].user);
        }

        function playCurrentStory() {
            standaloneMode = false;
            if (currentStoryUserIndex >= globalStories.length) {
                closeStoryViewer();
                return;
            }
            const group = globalStories[currentStoryUserIndex];
            if (currentStoryIndex >= group.stories.length) {
                currentStoryUserIndex++;
                currentStoryIndex = 0;
                playCurrentStory();
                return;
            }
            playStoryInternal(group.stories, group.user);
        }

        function playStoryInternal(storiesList, user) {
            const story = storiesList[currentStoryIndex];
            
            const progressContainer = document.getElementById('storyProgressContainer');
            progressContainer.innerHTML = '';
            storiesList.forEach((s, idx) => {
                const fillWidth = idx < currentStoryIndex ? '100%' : '0%';
                progressContainer.innerHTML += `<div class="story-progress-bar"><div class="story-progress-fill" id="storyProgress-${idx}" style="width: ${fillWidth};"></div></div>`;
            });
            
            document.getElementById('storyViewerName').innerText = user.name || user.username;
            document.getElementById('storyViewerAvatar').src = user.profilePicture || '/vylithra_logo.png';
            
            const imgEl = document.getElementById('storyViewerImage');
            const vidEl = document.getElementById('storyViewerVideo');
            
            if (story.mediaType === 'video') {
                imgEl.style.display = 'none';
                vidEl.style.display = 'block';
                vidEl.src = story.mediaUrl;
                vidEl.onended = nextStory;
            } else {
                vidEl.style.display = 'none';
                vidEl.src = '';
                imgEl.style.display = 'block';
                imgEl.src = story.mediaUrl;
            }
            
            fetch(`/api/stories/${story._id}/view`, { method: 'PUT', headers: { 'x-auth-token': localStorage.getItem('token') } });
            
            clearTimeout(storyTimeout);
            if (story.mediaType !== 'video') {
                let start = Date.now();
                const duration = 5000;
                const fillEl = document.getElementById(`storyProgress-${currentStoryIndex}`);
                
                function animateProgress() {
                    const elapsed = Date.now() - start;
                    const percent = Math.min(100, (elapsed / duration) * 100);
                    if(fillEl) fillEl.style.width = percent + '%';
                    
                    if (elapsed < duration && document.getElementById('storyViewerOverlay').classList.contains('active')) {
                        requestAnimationFrame(animateProgress);
                    }
                }
                requestAnimationFrame(animateProgress);
                storyTimeout = setTimeout(nextStory, duration);
            } else {
                 vidEl.ontimeupdate = () => {
                     const fillEl = document.getElementById(`storyProgress-${currentStoryIndex}`);
                     if (fillEl && vidEl.duration) {
                         fillEl.style.width = (vidEl.currentTime / vidEl.duration * 100) + '%';
                     }
                 };
            }
        }
        
        function nextStory() {
            clearTimeout(storyTimeout);
            currentStoryIndex++;
            if (standaloneMode) {
                if (currentStoryIndex >= standaloneStories.length) closeStoryViewer();
                else playStoryInternal(standaloneStories, standaloneStories[0].user);
            } else {
                playCurrentStory();
            }
        }
        
        function prevStory() {
            clearTimeout(storyTimeout);
            if (currentStoryIndex > 0) {
                currentStoryIndex--;
                if (standaloneMode) playStoryInternal(standaloneStories, standaloneStories[0].user);
                else playCurrentStory();
            } else if (currentStoryUserIndex > 0 && !standaloneMode) {
                currentStoryUserIndex--;
                currentStoryIndex = globalStories[currentStoryUserIndex].stories.length - 1;
                playCurrentStory();
            }
        }
        
        function closeStoryViewer() {
            clearTimeout(storyTimeout);
            document.getElementById('storyViewerOverlay').classList.remove('active');
            document.getElementById('storyViewerVideo').pause();
            document.getElementById('storyViewerVideo').src = '';
            renderStories(); 
        }
        // === END INSTAGRAM STORIES LOGIC ===

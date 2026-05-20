const fs = require('fs');

let serverJs = fs.readFileSync('server.js', 'utf8');

// Add model import
if (!serverJs.includes('const Story = require(\'./models/Story\');')) {
    serverJs = serverJs.replace('const Post = require(\'./models/Post\');', 'const Post = require(\'./models/Post\');\nconst Story = require(\'./models/Story\');');
}

// Add routes
const storyRoutes = `
// ==========================================
// 5.5 Stories API
// ==========================================

// Upload Story Media
app.post('/api/stories/upload', auth, (req, res) => {
    upload.single('storyMedia')(req, res, async (err) => {
        if (err) return res.status(400).json({ msg: err });
        if (!req.file) return res.status(400).json({ msg: 'No file selected!' });
        
        try {
            const filename = \`story-\${Date.now()}\${path.extname(req.file.originalname)}\`;
            const blob = await put(filename, req.file.buffer, {
                access: 'public',
                contentType: req.file.mimetype
            });
            
            const isVideo = req.file.mimetype.startsWith('video');
            
            const newStory = new Story({
                user: req.user.id,
                mediaUrl: blob.url,
                mediaType: isVideo ? 'video' : 'image'
            });
            await newStory.save();
            
            res.json(newStory);
        } catch (error) {
            console.error(error);
            res.status(500).send('Server Error');
        }
    });
});

// Get Feed Stories (Grouped by User)
app.get('/api/stories/feed', auth, async (req, res) => {
    try {
        const stories = await Story.find()
            .sort({ createdAt: 1 })
            .populate('user', 'name username profilePicture');
            
        // Group by user
        const grouped = {};
        stories.forEach(story => {
            if(!story.user) return;
            const userId = story.user._id.toString();
            if(!grouped[userId]) {
                grouped[userId] = {
                    user: story.user,
                    stories: [],
                    lastUpdated: story.createdAt
                };
            }
            grouped[userId].stories.push(story);
            if (new Date(story.createdAt) > new Date(grouped[userId].lastUpdated)) {
                grouped[userId].lastUpdated = story.createdAt;
            }
        });
        
        // Convert to array and sort by latest activity
        const feed = Object.values(grouped).sort((a, b) => new Date(b.lastUpdated) - new Date(a.lastUpdated));
        res.json(feed);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Get stories for specific user
app.get('/api/stories/user/:userId', auth, async (req, res) => {
    try {
        const stories = await Story.find({ user: req.params.userId })
            .sort({ createdAt: 1 })
            .populate('user', 'name username profilePicture');
        res.json(stories);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Mark story as viewed
app.put('/api/stories/:id/view', auth, async (req, res) => {
    try {
        const story = await Story.findById(req.params.id);
        if (!story) return res.status(404).json({ msg: 'Story not found' });
        
        if (!story.viewers.includes(req.user.id)) {
            story.viewers.push(req.user.id);
            await story.save();
        }
        res.json(story);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});
`;

if (!serverJs.includes('/api/stories/feed')) {
    serverJs = serverJs.replace('// 6. Admin Core System', storyRoutes + '\n// 6. Admin Core System');
    fs.writeFileSync('server.js', serverJs);
    console.log('Story routes injected successfully.');
} else {
    console.log('Story routes already exist.');
}

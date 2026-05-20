const mongoose = require('mongoose');

const PostSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    username: {
        type: String,
        required: true
    },
    isAnonymous: {
        type: Boolean,
        default: false
    },
    content: {
        type: String,
        required: true
    },
    tag: {
        type: String, // Kept for backward compatibility, sync with category if needed
        default: 'General'
    },
    title: {
        type: String
    },
    category: {
        type: String,
        enum: [
            'Global Affairs',
            'Technology & Innovation',
            'Business & Finance',
            'Science & Environment',
            'Arts & Culture',
            'Health & Wellness',
            'Sports & Athletics',
            'Education & Career',
            'Lifestyle & Travel',
            'Opinion & Commentary',
            'Other',
            // Legacy support
            'World News', 'Sports', 'Study', 'Animals', 'Coding', 'General'
        ],
        default: 'General'
    },
    videoUrl: {
        type: String
    },
    image: {
        type: String
    },
    attachment: {
        type: String // Path to file
    },
    type: {
        type: String,
        enum: ['quick', 'article', 'reel'],
        default: 'quick'
    },
    likes: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    comments: [{
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        username: String,
        text: String,
        createdAt: { type: Date, default: Date.now }
    }],
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Post', PostSchema);

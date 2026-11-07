const mongoose = require('mongoose');

const CommunityDiscussionSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    title: {
        type: String,
        required: true,
        trim: true
    },
    content: {
        type: String,
        required: true
    },
    likes: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    comments: [{
        user: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        },
        username: String,
        text: String,
        createdAt: {
            type: Date,
            default: Date.now
        }
    }],
    createdAt: {
        type: Date,
        default: Date.now
    }
});

const CommunityEventSchema = new mongoose.Schema({
    title: { type: String, required: true },
    description: { type: String, default: '' },
    date: { type: Date, default: Date.now },
    speaker: { type: String, default: 'Community Host' },
    link: { type: String, default: '' },
    rsvps: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }]
});

const CourseLessonSchema = new mongoose.Schema({
    title: { type: String, required: true },
    duration: { type: String, default: '15 mins' },
    content: { type: String, default: '' }
});

const CommunityCourseSchema = new mongoose.Schema({
    title: { type: String, required: true },
    description: { type: String, default: '' },
    instructor: { type: String, default: 'Vylithra Faculty' },
    level: { type: String, enum: ['Beginner', 'Intermediate', 'Advanced'], default: 'Beginner' },
    lessons: [CourseLessonSchema],
    enrolledUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }]
});

const CommunitySchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        unique: true,
        trim: true
    },
    slug: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
        trim: true
    },
    tagline: {
        type: String,
        default: ''
    },
    description: {
        type: String,
        default: ''
    },
    topic: {
        type: String,
        enum: ['Tech & AI', 'Writing & Books', 'Science', 'Philosophy', 'Art & Design', 'Business'],
        default: 'Tech & AI'
    },
    icon: {
        type: String,
        default: 'fa-brain'
    },
    bannerColor: {
        type: String,
        default: 'linear-gradient(135deg, #00f2fe 0%, #4facfe 100%)'
    },
    creator: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    members: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    discussions: [CommunityDiscussionSchema],
    events: [CommunityEventSchema],
    courses: [CommunityCourseSchema],
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Community', CommunitySchema);

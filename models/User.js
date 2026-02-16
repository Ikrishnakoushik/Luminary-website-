const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    username: {
        type: String,
        required: true,
        unique: true
    },
    email: {
        type: String,
        required: true,
        unique: true
    },
    password: {
        type: String,
        required: true
    },
    role: {
        type: String,
        enum: ['publisher', 'reader'],
        default: 'reader'
    },
    displayName: {
        type: String,
        default: ''
    },
    bio: {
        type: String,
        default: ''
    },
    profilePicture: {
        type: String,
        default: '' // URL or path to image
    },
    loginHistory: [{
        type: Date,
        default: Date.now
    }],
    resetPasswordOtp: {
        type: String
    },
    resetPasswordExpires: {
        type: Date
    },
    isVerified: {
        type: Boolean,
        default: false
    },
    verificationOtp: {
        type: String
    },
    verificationExpires: {
        type: Date
    },
    preferences: [{
        type: String,
        enum: ['World News', 'Sports', 'Study', 'Animals', 'Coding', 'Other']
    }],
    projects: [{
        title: { type: String, required: true },
        description: { type: String },
        link: { type: String },
        icon: { type: String, default: '🚀' }
    }],
    socials: {
        twitter: { type: String, default: '' },
        github: { type: String, default: '' },
        linkedin: { type: String, default: '' }
    }
});

module.exports = mongoose.model('User', UserSchema);

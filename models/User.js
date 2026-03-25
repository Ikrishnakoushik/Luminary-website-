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
    firebaseUid: {
        type: String,
        default: null,
        index: true
    },
    password: {
        type: String
    },
    role: {
        type: String,
        enum: ['publisher', 'reader', 'admin'],
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
    unlockedDownloads: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Book'
    }],
    activeSessions: [{
        sessionId: { type: String, required: true },
        userAgent: { type: String },
        device: { type: String },
        browser: { type: String },
        os: { type: String },
        ip: { type: String },
        lastActive: { type: Date, default: Date.now }
    }],
    twoFactorSecret: {
        type: String,
        default: null
    },
    isTwoFactorEnabled: {
        type: Boolean,
        default: false
    },
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
    adminGatewayOtp: {
        type: String,
        default: null
    },
    adminGatewayOtpExpires: {
        type: Date,
        default: null
    },
    followers: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    following: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    razorpayAccountId: {
        type: String,
        default: ''
    },
    // Manual Payment Methods
    preferredPaymentMethod: {
        type: String,
        enum: ['razorpay', 'paypal', 'upi', 'manual'],
        default: 'manual'
    },
    paymentHandle: {
        type: String, // email for paypal, id for upi, etc
        default: ''
    },
    // Publisher Earnings & Withdrawals
    walletBalance: {
        type: Number,
        default: 0
    },
    totalEarned: {
        type: Number,
        default: 0
    },
    withdrawalHistory: [{
        amount: { type: Number, required: true },
        date: { type: Date, default: Date.now },
        status: { type: String, enum: ['pending', 'completed', 'failed'], default: 'pending' },
        method: { type: String },
        details: { type: String }
    }],
    purchasedBooks: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Book'
    }],
    publishedBooks: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Book'
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

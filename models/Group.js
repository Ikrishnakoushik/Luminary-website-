const mongoose = require('mongoose');

const GroupSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true
    },
    description: {
        type: String,
        default: ''
    },
    avatar: {
        type: String,
        default: ''
    },
    type: {
        type: String,
        enum: ['group', 'channel'],
        default: 'group'
    },
    isPublic: {
        type: Boolean,
        default: false
    },
    admin: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    members: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    keyEnvelopes: [{
        user: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        },
        encryptedKey: {
            type: String,
            default: null
        },
        iv: {
            type: String,
            default: null
        },
        creatorPublicKey: {
            type: String,
            default: null
        }
    }],
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Group', GroupSchema);

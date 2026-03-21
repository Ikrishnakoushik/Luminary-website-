const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
    sender: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    receiver: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: false
    },
    groupId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Group',
        required: false
    },
    content: {
        type: String,
        required: true
    },
    attachmentUrl: {
        type: String,
        default: null
    },
    attachmentType: {
        type: String,
        enum: ['image', 'video', 'file', 'none'],
        default: 'none'
    },
    read: {
        type: Boolean,
        default: false
    }
}, { timestamps: true });

module.exports = mongoose.model('Message', MessageSchema);

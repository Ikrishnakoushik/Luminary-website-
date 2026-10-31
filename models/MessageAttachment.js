const mongoose = require('mongoose');

const MessageAttachmentSchema = new mongoose.Schema({
    filename: {
        type: String,
        required: true
    },
    contentType: {
        type: String,
        default: 'application/octet-stream'
    },
    data: {
        type: Buffer,
        required: true
    },
    size: {
        type: Number,
        default: 0
    }
}, { timestamps: true });

module.exports = mongoose.model('MessageAttachment', MessageAttachmentSchema);

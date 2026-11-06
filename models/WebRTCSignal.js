const mongoose = require('mongoose');

const WebRTCSignalSchema = new mongoose.Schema({
    to: {
        type: String,
        required: true,
        index: true
    },
    from: {
        type: String,
        required: true
    },
    type: {
        type: String,
        required: true
    },
    payload: {
        type: mongoose.Schema.Types.Mixed,
        required: true
    },
    createdAt: {
        type: Date,
        default: Date.now,
        expires: 60 // MongoDB TTL index: automatically purges signals after 60s
    }
});

module.exports = mongoose.models.WebRTCSignal || mongoose.model('WebRTCSignal', WebRTCSignalSchema);

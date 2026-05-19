const mongoose = require('mongoose');

const heroBannerSchema = new mongoose.Schema({
    title: {
        type: String,
        required: true,
        trim: true
    },
    subtitle: {
        type: String,
        required: true
    },
    imageUrl: {
        type: String,
        required: true
    },
    isActive: {
        type: Boolean,
        default: false
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('HeroBanner', heroBannerSchema);

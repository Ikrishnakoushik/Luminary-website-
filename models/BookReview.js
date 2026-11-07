const mongoose = require('mongoose');

const BookReviewSchema = new mongoose.Schema({
    book: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Book',
        required: true,
        index: true
    },
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    score: {
        type: Number,
        required: true,
        min: 1,
        max: 5
    },
    reviewText: {
        type: String,
        default: '',
        maxlength: 2000
    },
    verifiedReader: {
        type: Boolean,
        default: false
    },
    helpfulVotes: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    createdAt: {
        type: Date,
        default: Date.now
    }
}, { timestamps: true });

BookReviewSchema.index({ book: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('BookReview', BookReviewSchema);


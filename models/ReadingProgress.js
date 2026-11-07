const mongoose = require('mongoose');

const BookmarkSchema = new mongoose.Schema({
    chapter: { type: String, default: '' },
    page: { type: Number, default: 1 },
    note: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now }
});

const ReadingProgressSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    book: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Book',
        required: true
    },
    currentPage: {
        type: Number,
        default: 1
    },
    totalPages: {
        type: Number,
        default: 1
    },
    progressPercent: {
        type: Number,
        default: 0
    },
    bookmarks: [BookmarkSchema],
    lastReadAt: {
        type: Date,
        default: Date.now
    }
}, { timestamps: true });

ReadingProgressSchema.index({ user: 1, book: 1 }, { unique: true });

module.exports = mongoose.model('ReadingProgress', ReadingProgressSchema);

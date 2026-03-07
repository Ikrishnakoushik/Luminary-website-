const mongoose = require('mongoose');

const BookSchema = new mongoose.Schema({
    title: {
        type: String,
        required: true
    },
    author: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    penName: {
        type: String,
        default: ''
    },
    description: {
        type: String,
        required: true
    },
    coverImage: {
        type: String,
        default: ''
    },
    price: {
        type: Number,
        default: 0
    },
    content: {
        type: String, // Storing HTML or structured JSON depending on editor
        required: true
    },
    isPublished: {
        type: Boolean,
        default: true
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Book', BookSchema);

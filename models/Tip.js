const mongoose = require('mongoose');

const TipSchema = new mongoose.Schema({
    fromUser: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    toCreator: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    amount: {
        type: Number,
        required: true,
        min: 1
    },
    currency: {
        type: String,
        default: 'INR'
    },
    message: {
        type: String,
        default: '',
        maxlength: 300
    },
    isAnonymous: {
        type: Boolean,
        default: false
    },
    paymentGateway: {
        type: String,
        enum: ['wallet', 'razorpay', 'paypal', 'mock'],
        default: 'wallet'
    },
    status: {
        type: String,
        enum: ['pending', 'completed', 'failed'],
        default: 'completed'
    }
}, { timestamps: true });

module.exports = mongoose.model('Tip', TipSchema);

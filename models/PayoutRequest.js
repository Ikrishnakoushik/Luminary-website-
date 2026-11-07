const mongoose = require('mongoose');

const PayoutRequestSchema = new mongoose.Schema({
    creator: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    amount: {
        type: Number,
        required: true,
        min: 100 // Minimum payout threshold e.g. ₹100
    },
    currency: {
        type: String,
        default: 'INR'
    },
    payoutMethod: {
        type: String,
        enum: ['upi', 'bank', 'paypal'],
        required: true
    },
    payoutDetails: {
        type: String,
        required: true
    },
    status: {
        type: String,
        enum: ['pending', 'approved', 'processed', 'rejected'],
        default: 'pending'
    },
    adminNotes: {
        type: String,
        default: ''
    },
    processedAt: {
        type: Date
    }
}, { timestamps: true });

module.exports = mongoose.model('PayoutRequest', PayoutRequestSchema);


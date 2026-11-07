const mongoose = require('mongoose');

const SubscriptionSchema = new mongoose.Schema({
    subscriber: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    creator: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    tierName: {
        type: String,
        default: 'Supporter'
    },
    price: {
        type: Number,
        required: true
    },
    currency: {
        type: String,
        default: 'INR'
    },
    status: {
        type: String,
        enum: ['active', 'cancelled', 'expired'],
        default: 'active',
        index: true
    },
    startDate: {
        type: Date,
        default: Date.now
    },
    expiresAt: {
        type: Date,
        required: true,
        index: true
    },
    autoRenew: {
        type: Boolean,
        default: true
    }
}, { timestamps: true });

SubscriptionSchema.index({ subscriber: 1, creator: 1 });

module.exports = mongoose.model('Subscription', SubscriptionSchema);

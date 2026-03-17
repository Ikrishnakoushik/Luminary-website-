const mongoose = require('mongoose');

const CouponSchema = new mongoose.Schema({
    code: {
        type: String,
        required: true,
        unique: true,
        uppercase: true,
        trim: true
    },
    discountType: {
        type: String,
        enum: ['percentage', 'fixed'],
        default: 'percentage'
    },
    discountPercentage: {
        type: Number,
        min: 1,
        max: 100
    },
    discountAmount: {
        type: Number,
        min: 1
    },
    minPurchaseAmount: {
        type: Number,
        default: 0
    },
    maxUses: {
        type: Number,
        default: 100
    },
    usedCount: {
        type: Number,
        default: 0
    },
    expiryDate: {
        type: Date,
        required: true
    },
    status: {
        type: String,
        enum: ['active', 'pending'],
        default: 'active'
    },
    generatedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    isActive: {
        type: Boolean,
        default: true
    }
}, { timestamps: true });

module.exports = mongoose.model('Coupon', CouponSchema);

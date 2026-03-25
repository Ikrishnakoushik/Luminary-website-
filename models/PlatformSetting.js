const mongoose = require('mongoose');

const platformSettingSchema = new mongoose.Schema({
    registrationEnabled: {
        type: Boolean,
        default: true
    },
    maintenanceMode: {
        type: Boolean,
        default: false
    },
    platformFee: {
        type: Number,
        default: 10 // Percentage cut taken from publisher sales
    },
    downloadFeePercentage: {
        type: Number,
        default: 50 // Percentage calculation for dynamic Premium Book valid downloads
    }
}, { timestamps: true });

// We enforce a singleton pattern by providing a fixed ID when creating/querying this document
module.exports = mongoose.model('PlatformSetting', platformSettingSchema);

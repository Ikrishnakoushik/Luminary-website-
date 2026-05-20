require('dotenv').config();
const mongoose = require('mongoose');
const PlatformSetting = require('./models/PlatformSetting');
mongoose.connect(process.env.MONGO_URI).then(async () => {
    const result = await PlatformSetting.updateMany({}, { $set: { ipBlacklist: [] } });
    console.log('Successfully cleared IP blacklist. Result:', result);
    process.exit(0);
}).catch(err => {
    console.error(err);
    process.exit(1);
});

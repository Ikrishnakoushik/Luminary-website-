require('dotenv').config();
const mongoose = require('mongoose');
const PlatformSetting = require('./models/PlatformSetting');

mongoose.connect(process.env.MONGO_URI).then(async () => {
    let settings = await PlatformSetting.findOne();
    if (!settings) {
        console.log("No settings found. Creating one.");
        settings = new PlatformSetting({
            firewallEnabled: false, // DISABLE FIREWALL TEMPORARILY TO SEE IF 403 GOES AWAY!
            ipBlacklist: []
        });
        await settings.save();
        console.log("Created settings:", settings);
    } else {
        console.log("Settings found:", settings);
        settings.firewallEnabled = false; // Disable it just to be safe
        settings.ipBlacklist = [];
        await settings.save();
        console.log("Updated settings to disable firewall and clear blacklist.");
    }
    process.exit(0);
}).catch(err => {
    console.error(err);
    process.exit(1);
});

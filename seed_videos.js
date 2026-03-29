const mongoose = require('mongoose');
require('dotenv').config();
const User = require('./models/User');
const Post = require('./models/Post');

// 15 High-Speed Global CDN MP4s
const videos = [
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', desc: "The legendary Big Buck Bunny returns! 🐰✨ #cinema #animation" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', desc: "A surreal dive into Elephant's Dream. 🐘💭 #surreal #dreams" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4', desc: "Ignite your passion with Bigger Blazes! 🔥 #fire #vfx" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4', desc: "The ultimate escape. Watch till the end. 🏃‍♂️💨 #action #thriller" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4', desc: "Having fun yet? Enjoy this classic cut! 🎉 #classic #movies" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4', desc: "Take a joyride into the digital cosmos. 🚗🌌 #neon #cyberpunk" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4', desc: "Absolutely melting down! Insane visual fidelity. 🤯 #vfxbreakdown" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4', desc: "Sintel's quest for her dragon. A masterpiece. 🐉🗡️ #fantasy #sintel" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4', desc: "Racing through the outback! Pure adrenaline! 🏎️🏜️ #drifting #jdm" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4', desc: "Tears of Steel: Cyberpunk Sci-Fi showcase! 🦾🤖 #scifi #blender" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4', desc: "Cruising in style. VROOM VROOM. 🚘🌴 #carguy #review" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4', desc: "The ultimate rally! Bullrun madness! 🏎️🔥 #racing" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4', desc: "What can you get for a grand? Let's find out. 💸🚗 #budget #cars" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', desc: "Wait... is that a giant butterfly? 🦋😲 #nature #wild" },
    { url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4', desc: "Finding the dragon nest... truly breathtaking. 🏔️🐲 #epic" }
];

async function runSeed() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('[+] Connected to Native MongoDB...');
        
        let targetUser = await User.findOne();
        if(!targetUser) {
            console.log('[!] Executing mock user creation protocol...');
            targetUser = new User({ email: 'reels@vylithra.in', password: 'password123', username: 'VylithraStudios', displayName: 'Vylithra Creator Suite' });
            await targetUser.save();
        }

        console.log(`[+] Validated Active User ID: ${targetUser._id} (@${targetUser.username})`);
        
        // Loop and inject exactly 15 verified MP4 Post Objects directly into the NoSQL pipeline
        for (let i = 0; i < videos.length; i++) {
            const reel = new Post({
                user: targetUser._id,
                username: targetUser.username,
                content: videos[i].desc,
                videoUrl: videos[i].url, // Bypass file attachments and bind directly to the CDNs
                likes: [],
                comments: []
            });
            await reel.save();
            console.log(`[>>] Successfully Seeded Reel Asset ${i + 1}/15`);
        }
        
        console.log('[-] Reel Seeding Protocol Confirmed & Closed Natively.');
        process.exit(0);
    } catch (e) {
        console.error('[FATAL]', e);
        process.exit(1);
    }
}

runSeed();

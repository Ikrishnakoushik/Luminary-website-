const mongoose = require('mongoose');
require('dotenv').config();
const User = require('./models/User');
const Post = require('./models/Post');

// 15 High-Speed Global HTTPS CDN MP4s (W3C / Zen CDN / Archive.org)
const videos = [
    { url: 'https://vjs.zencdn.net/v/oceans.mp4', desc: "Diving into the deep blue... 🌊🐢 #nature #ocean" },
    { url: 'https://media.w3.org/2010/05/sintel/trailer.mp4', desc: "Sintel Trailer - The search for her dragon! 🐉🗡️ #animation #epic" },
    { url: 'https://media.w3.org/2010/05/bunny/trailer.mp4', desc: "Big Buck Bunny Trailer - Classic! 🐰✨ #blender #funny" },
    { url: 'https://media.w3.org/2010/05/bunny/movie.mp4', desc: "Big Buck Bunny Full Cut - Don't mess with him! 🐻💥 #classic #action" },
    { url: 'https://media.w3.org/2010/05/video/movie_300.mp4', desc: "Bear in the woods... 🐻🌲 #wildlife #nature" },
    { url: 'https://vjs.zencdn.net/v/oceans.mp4', desc: "Pelicans taking flight! 🕊️🌅 #birds #sunset" },
    { url: 'https://media.w3.org/2010/05/sintel/trailer.mp4', desc: "The fight scene from Sintel... insane choreography! ⚔️🔥 #vfx #scifi" },
    { url: 'https://media.w3.org/2010/05/bunny/trailer.mp4', desc: "When the squirrels attack... pure chaos 😂🐿️ #comedy" },
    { url: 'https://media.w3.org/2010/05/bunny/movie.mp4', desc: "Revenge of the Bunny! 🐇💣 #shortfilm" },
    { url: 'https://media.w3.org/2010/05/video/movie_300.mp4', desc: "Just a relaxing stream... 🏞️💧 #aesthetic" },
    { url: 'https://vjs.zencdn.net/v/oceans.mp4', desc: "Coral reef beauty perfectly captured. 🐠🐡 #underwater" },
    { url: 'https://media.w3.org/2010/05/sintel/trailer.mp4', desc: "Wait for the drop... Sintel's journey is unmatched 🏔️❄️" },
    { url: 'https://media.w3.org/2010/05/bunny/trailer.mp4', desc: "Mashing up my favorite Blender shorts today! 🎬🎨" },
    { url: 'https://media.w3.org/2010/05/bunny/movie.mp4', desc: "The animation quality on this is still incredible. #render" },
    { url: 'https://media.w3.org/2010/05/video/movie_300.mp4', desc: "Ending the day with some nature vibes. 🌿🍃 #chill" }
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

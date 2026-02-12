const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Post = require('./models/Post');

// Database Connection
const MONGO_URI = 'mongodb://localhost:27017/everything_spread';

const categories = ['World News', 'Sports', 'Study', 'Animals', 'Coding', 'Other', 'General'];

const realNames = [
    "Emma Watson", "Liam Neeson", "Olivia Rodrigo", "Noah Centineo", "Ava Max",
    "Elijah Wood", "Sophia Turner", "James Bond", "Isabella Rossellini", "Benjamin Franklin",
    "Mia Khalifa", "Lucas Films", "Charlotte Web", "Henry Cavill", "Amelia Earhart",
    "Alexander Hamilton", "Harper Lee", "Michael Jordan", "Evelyn Waugh", "Daniel Radcliffe"
];

const getPhoto = (category, index) => {
    return `https://placehold.co/800x400?text=${category}+${index}`;
};

const getVideo = (category) => {
    const videos = [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        'https://www.youtube.com/watch?v=L_jWHffIx5E',
        'https://www.youtube.com/watch?v=9bZkp7q19f0',
    ];
    return videos[Math.floor(Math.random() * videos.length)];
};

const seedData = async () => {
    try {
        await mongoose.connect(MONGO_URI);
        console.log('MongoDB Connected...');

        console.log('Clearing old data...');
        await User.deleteMany({});
        await Post.deleteMany({});

        console.log('Creating 20 Publishers with Real Names...');

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash('password123', salt);

        for (let i = 0; i < realNames.length; i++) {
            const fullName = realNames[i];
            const username = fullName.replace(' ', '').toLowerCase() + (i + 1); // e.g., emmawatson1
            const email = `${username}@example.com`;

            // Generate a consistent "real" face avatar
            const profilePicture = `https://i.pravatar.cc/150?u=${username}`;

            const user = new User({
                username,
                email,
                password: hashedPassword,
                role: 'publisher',
                isVerified: true,
                displayName: fullName,
                profilePicture: profilePicture,
                bio: `Hi, I'm ${fullName}. I love sharing insights about ${categories[i % categories.length]}. content creator & enthusiast.`
            });
            await user.save();
            console.log(`Created User: ${fullName} (${username})`);

            // Create 2-4 Posts for this user
            const numPosts = Math.floor(Math.random() * 3) + 2;
            for (let j = 0; j < numPosts; j++) {
                const category = categories[Math.floor(Math.random() * categories.length)];
                const hasVideo = Math.random() > 0.4;

                const newPost = new Post({
                    user: user._id,
                    username: user.username, // Keeping username for reference, though population handles display
                    title: `Why ${category} Matters: A Perspective by ${fullName.split(' ')[0]}`,
                    content: `In this post, ${fullName} explores the intricate details of ${category}. We believe that understanding ${category} is key to the future. Join the discussion below!`,
                    category: category,
                    tag: category,
                    type: 'article',
                    videoUrl: hasVideo ? getVideo(category) : '',
                    image: getPhoto(category, j),
                    createdAt: new Date(Date.now() - Math.floor(Math.random() * 86400000 * 15))
                });

                await newPost.save();
            }
        }

        console.log('Seeding Complete! Real names, avatars, and rich content.');
        process.exit();
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

seedData();

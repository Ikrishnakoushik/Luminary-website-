const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Post = require('./models/Post');

// Database Connection
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/everything_spread';

const categories = ['World News', 'Sports', 'Study', 'Animals', 'Coding', 'Other', 'General'];

const realNames = [
    "Emma Watson", "Liam Neeson", "Olivia Rodrigo", "Noah Centineo", "Ava Max",
    "Elijah Wood", "Sophia Turner", "James Bond", "Isabella Rossellini", "Benjamin Franklin",
    "Mia Khalifa", "Lucas Films", "Charlotte Web", "Henry Cavill", "Amelia Earhart",
    "Alexander Hamilton", "Harper Lee", "Michael Jordan", "Evelyn Waugh", "Daniel Radcliffe"
];

const videoLibrary = {
    'Coding': ['https://www.youtube.com/watch?v=F2JC8h1CslY', 'https://www.youtube.com/watch?v=SqcY0GlETPk', 'https://www.youtube.com/watch?v=kQtjlYth2SU', 'https://www.youtube.com/watch?v=8ndj716yWQM', 'https://www.youtube.com/watch?v=bMknfKXIFA8'],
    'World News': ['https://www.youtube.com/watch?v=_1cT-19a9N4', 'https://www.youtube.com/watch?v=ysz5S6PUM-U', 'https://www.youtube.com/watch?v=P_q3BjrXsQg', 'https://www.youtube.com/watch?v=ysz5S6PUM-U'],
    'Sports': ['https://www.youtube.com/watch?v=3sL0omwElxw', 'https://www.youtube.com/watch?v=XhP3Xh4LMA8', 'https://www.youtube.com/watch?v=6JqgC3YJb_4', 'https://www.youtube.com/watch?v=2HkdM2fH3eQ'],
    'Animals': ['https://www.youtube.com/watch?v=QAveHy5QaaM', 'https://www.youtube.com/watch?v=_S7WEVLbQ-Y', 'https://www.youtube.com/watch?v=2g6gwwa_iA0', 'https://www.youtube.com/watch?v=FW4Cj7x8jys'],
    'Study': ['https://www.youtube.com/watch?v=jfKfPfyJRdk', 'https://www.youtube.com/watch?v=5qap5aO4i9A', 'https://www.youtube.com/watch?v=9M4XKi2z4DA', 'https://www.youtube.com/watch?v=lTRiuFIWV54'],
    'Other': ['https://www.youtube.com/watch?v=36YnV9STBqc', 'https://www.youtube.com/watch?v=LXb3EKWsInQ', 'https://www.youtube.com/watch?v=ysz5S6PUM-U'],
    'General': ['https://www.youtube.com/watch?v=n61ULEU7CO0', 'https://www.youtube.com/watch?v=9bZkp7q19f0', 'https://www.youtube.com/watch?v=CevxZvSJLk8']
};

const contentLibrary = {
    'Coding': [
        "One of the biggest challenges I faced when starting with React was understanding the useEffect hook. It seems simple on the surface, but the dependency array can be a real trap. Once I mastered it, however, my application performance improved drastically.",
        "Choosing the right tech stack is often more about the team's familiarity than the raw performance of the framework. I've seen successful products built on 'outdated' stacks simply because the developers knew the tools inside out.",
        "Debugging is an art form. It's not just about fixing errors; it's about understanding the flow of data. I spent three hours yesterday chasing a null pointer, only to realize I was passing the wrong props.",
        "The shift towards server-side rendering with Next.js has been a game changer for SEO. We migrated our entire marketing site and saw a 40% increase in organic traffic within two weeks.",
        "Clean code is not just about aesthetics; it's about maintainability. Writing comments is good, but writing self-documenting code is better. Always optimized for the next person who has to read your work.",
        "Scalability isn't just a buzzword; it's a necessity. When designing a system, you have to assume it will need to handle 10x the traffic in six months. Planning for failure is the hallmark of a senior engineer.",
        "The open source community is the backbone of modern software. Contributing back, even if it's just documentation fixes, is a moral obligation for those of us who benefit from these free tools.",
        "AI coding assistants are changing the game, but they aren't replacing us. They are making us faster. The developer of the future will be defined by their ability to orchestrate AI tools effectively."
    ],
    'Sports': [
        "The sheer determination required to run a marathon is underestimated. It's not the physical fatigue that gets you; it's the mental wall at mile 20. Pushing past that is where the real race begins.",
        "Tactical analysis in modern football has reached a new level. It's no longer just about formations; it's about pressing triggers and transition phases. Watching a team execute a high press perfectly is like watching a synchronized dance.",
        "Recovery is just as important as training. You can hit the gym seven days a week, but if you aren't sleeping and eating right, you're just breaking your body down without building it back up.",
        "There is something magical about the atmosphere in a packed stadium. The roar of the crowd, the tension in the air—it's an energy you can't replicate anywhere else. It reminds us why we love this game.",
        "Underdogs stories are the lifeblood of sports. Seeing a team that everyone counted out rise to the occasion and defeat the giants is the ultimate inspiration.",
        "The mental aspect of elite sports is often what separates the good from the great. Visualization techniques used by Olympians can be applied to everyday life to achieve our own goals.",
        "Youth development is crucial for the longevity of any sport. Investing in grassroots programs ensures that the next generation of talent has the opportunity to shine."
    ],
    'General': [
        "Sometimes, the most productive thing you can do is take a break. We live in a culture that glorifies hustle, but burnout is real. Stepping away for a day often leads to better ideas than grinding through the exhaustion.",
        "I've been thinking a lot lately about the impact of social media on our attention spans. It's getting harder to sit down and read a book without reaching for my phone every ten minutes.",
        "Creativity is not a talent; it's a habit. You have to show up and do the work, even when you don't feel inspired. The best ideas usually come while you're working, not while you're waiting for lightning to strike.",
        "Kindness costs nothing, but it means everything. A simple smile or a thank you can change someone's entire day. We often underestimate the power of small gestures.",
        "Learning a new skill as an adult is humbling. It reminds you what it's like to be a beginner again, to make mistakes, and to improve slowly. It keeps the mind sharp.",
        "The importance of community cannot be overstated. We are social creatures, and having a support network is vital for our mental health and well-being.",
        "Sustainability is the challenge of our generation. Small changes in our daily habits, when multiplied by millions of people, can have a massive impact on the planet."
    ]
};

const getPhoto = (category, index) => {
    const seed = category.charCodeAt(0) * 100 + index;
    return `https://picsum.photos/seed/${seed}/800/400`;
};

const getVideo = (category) => {
    const list = videoLibrary[category] || videoLibrary['General'];
    return list[Math.floor(Math.random() * list.length)];
};

const generateBookLikeContent = (author, category) => {
    const pool = contentLibrary[category] || contentLibrary['General'];

    // Generate 5-8 "Chapters"
    const numChapters = Math.floor(Math.random() * 4) + 5;
    let fullText = `**Foreword by ${author}**\n\n`;

    // Intro
    fullText += `Welcome to this comprehensive guide on **${category}**. Over the next few pages, we will explore every facet of this fascinating topic. Sit back, relax, and enjoy the journey.\n\n`;

    // Chapters
    for (let c = 1; c <= numChapters; c++) {
        fullText += `### Chapter ${c}: The ${['Beginning', 'Journey', 'Challenge', 'Solution', 'Future', 'Impact', 'Reality', 'Dream'][c - 1] || 'Details'}\n\n`;

        // Add 3-5 paragraphs per chapter
        const parasInChapter = Math.floor(Math.random() * 3) + 3;
        for (let p = 0; p < parasInChapter; p++) {
            const para = pool[Math.floor(Math.random() * pool.length)];
            fullText += para + "\n\n";
        }

        // Add a blockquote occasionally
        if (Math.random() > 0.7) {
            fullText += `> "The essence of ${category} lies in its ability to transform lives."\n\n`;
        }
    }

    // Conclusion
    fullText += `### Final Thoughts\n\nThank you for reading this extensive piece. I hope it has provided you with a new perspective on ${category}. Until next time.\n\n— ${author}`;

    return fullText;
};

const seedData = async () => {
    try {
        if (mongoose.connection.readyState !== 1) {
            await mongoose.connect(MONGO_URI);
            console.log('MongoDB Connected...');
        }

        console.log('Clearing old data...');
        await User.deleteMany({});
        await Post.deleteMany({});

        console.log('Creating 20 Publishers with Book-Like Content...');

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash('password123', salt);

        for (let i = 0; i < realNames.length; i++) {
            const fullName = realNames[i];
            const username = fullName.replace(' ', '').toLowerCase() + (i + 1);
            const email = `${username}@example.com`;
            const profilePicture = `https://i.pravatar.cc/150?u=${username}`;
            const expertCategory = categories[i % categories.length];

            const user = new User({
                username,
                email,
                password: hashedPassword,
                role: 'publisher',
                isVerified: true,
                displayName: fullName,
                profilePicture: profilePicture,
                bio: `Hi, I'm ${fullName}. I write full-length books and guides about ${expertCategory}.`
            });
            await user.save();
            console.log(`Created User: ${fullName} (${username})`);

            // Create 3-5 Posts
            const numPosts = Math.floor(Math.random() * 3) + 3;
            for (let j = 0; j < numPosts; j++) {
                const category = (Math.random() > 0.3) ? expertCategory : categories[Math.floor(Math.random() * categories.length)];
                const hasVideo = Math.random() > 0.6;

                const titles = [
                    `The Ultimate Manifesto on ${category}`,
                    `A 10-Page Deep Dive into ${category}`,
                    `Everything You Need to Know About ${category}`,
                    `The Complete History of ${category}`,
                    `Why ${category} Will Define The Next Decade`
                ];
                const title = titles[Math.floor(Math.random() * titles.length)];

                // Generate MASSIVE Content
                const content = generateBookLikeContent(fullName, category);

                const newPost = new Post({
                    user: user._id,
                    username: user.username,
                    title: title,
                    content: content,
                    category: category,
                    tag: category,
                    type: 'article',
                    videoUrl: hasVideo ? getVideo(category) : '',
                    image: getPhoto(category, j + i),
                    createdAt: new Date(Date.now() - Math.floor(Math.random() * 86400000 * 30))
                });

                await newPost.save();
            }
        }

        console.log('Seeding Complete! Massive book-like articles generated.');
        // process.exit(); // Don't exit process if called from server
        return true;
    } catch (err) {
        console.error(err);
        // process.exit(1);
        throw err;
    }
};

if (require.main === module) {
    seedData().then(() => process.exit());
}

module.exports = seedData;

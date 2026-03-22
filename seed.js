require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { faker } = require('@faker-js/faker');

const User = require('./models/User');
const Post = require('./models/Post');
const Book = require('./models/Book');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/vylithra';

const jobTitles = [
    'Senior Product Designer', 'UI/UX Lead', 'Full-Stack Developer', 'Frontend Engineer', 
    'Software Architect', 'Product Manager', 'Creative Director', 'DevOps Engineer', 
    'Data Scientist', 'Design Systems Engineer', 'Founder & CEO', 'VP of Engineering'
];

const postSentences = [
    "Just finished wireframing the new dashboard. Thinking deeply about user friction.",
    "Switched our main app to Next.js 14 and the performance gains are incredible. Server components are the future.",
    "Design systems aren't just about components; they are about communication between design and engineering.",
    "Been exploring the new Figma variables. The potential for multi-brand design systems is immense.",
    "As software scales, simplicity becomes the hardest pattern to maintain. Keep your architecture clean.",
    "Refactoring a legacy codebase today. Found some interesting historical patterns.",
    "What are everyone's thoughts on Tailwind CSS for enterprise applications?",
    "Typography is 90% of web design. If your layout looks off, check your line-height and letter-spacing.",
    "Just deployed our new load balancer configuration. Zero downtime is always a beautiful thing.",
    "User research uncovered massive friction in our checkout flow. Always talk to your users!",
    "Exploring the possibilities of WebGL for our new landing page. Performance is key.",
    "The transition from REST to GraphQL has dramatically changed our frontend data fetching strategy."
];

const professionalBookTitles = [
    "The Figma Handbook", "Clean Architecture in Node.js", "Mastering React 18: Server Components", 
    "Building Scalable Systems", "The Comprehensive Guide to Design Systems", "Practical TypeScript", 
    "The Advanced Node.js Handbook", "Modern CSS Layouts: Grid & Flexbox", "The Minimalist UI Designer", 
    "Enterprise Product Management", "Micro Frontends in Action", "Designing with Accessibility",
    "The Go Programming Handbook", "Kubernetes Native Microservices", "Psychology of Web Design",
    "Advanced Animation with Framer Motion", "Serverless Architectures on AWS", "Leading Engineering Teams",
    "The UX Researcher's Field Guide", "Zero to One: SaaS Strategies", "Refactoring Legacy Code",
    "Tailwind CSS in Enterprise", "Building Secure Web Applications", "The Art of Typography",
    "Web Performance Optimization"
];

const imageThemes = ['workspace', 'technology', 'design', 'code', 'laptop', 'minimalist', 'office', 'computer', 'architecture', 'abstract'];

async function seedDB() {
    try {
        console.log('Connecting to database...');
        await mongoose.connect(MONGO_URI);
        console.log('Connected.');

        const salt = await bcrypt.genSalt(10);
        const defaultPassword = await bcrypt.hash('password123', salt);

        // ==========================================
        // 1. Generate 25 Realistic Users & Posts
        // ==========================================
        console.log('Generating 25 Professional Users (Readers)...');
        const readers = [];
        for (let i = 0; i < 25; i++) {
            const job = faker.helpers.arrayElement(jobTitles);
            const company = faker.company.name();
            readers.push({
                username: faker.internet.username() + '_' + faker.string.numeric(4),
                email: faker.internet.email(),
                password: defaultPassword,
                role: 'reader',
                displayName: faker.person.fullName(),
                bio: `${job} at ${company}. Passionate about building great software.`,
                profilePicture: `https://i.pravatar.cc/150?u=${faker.string.uuid()}`
            });
        }
        
        const createdReaders = await User.insertMany(readers);
        console.log(`Successfully created ${createdReaders.length} reader users.`);

        console.log('Generating 100 Professional Posts...');
        const posts = [];
        const categories = [
            'Global Affairs', 'Technology & Innovation', 'Business & Finance', 
            'Science & Environment', 'Arts & Culture', 'Health & Wellness', 
            'Sports & Athletics', 'Education & Career', 'Lifestyle & Travel', 
            'Opinion & Commentary', 'Coding'
        ];
        
        for (let i = 0; i < createdReaders.length; i++) {
            const user = createdReaders[i];
            const theme = imageThemes[i % imageThemes.length];
            const coreInsight = faker.helpers.arrayElement(postSentences);
            
            posts.push({
                user: user._id,
                username: user.username,
                content: `${coreInsight} \n\n${faker.lorem.paragraphs(1)}`,
                title: faker.company.catchPhrase(),
                category: faker.helpers.arrayElement(categories),
                type: 'article',
                image: `https://loremflickr.com/800/600/${theme}?lock=${faker.string.numeric(5)}`,
                createdAt: faker.date.recent({ days: 30 })
            });
        }
        await Post.insertMany(posts);
        console.log(`Successfully created ${posts.length} tech-focused posts.`);

        // ==============================================
        // 2. Generate 25 Publisher Users & Technical Books
        // ==============================================
        console.log('Generating 25 Professional Publisher Users...');
        const publishers = [];
        for (let i = 0; i < 25; i++) {
            const job = faker.helpers.arrayElement(jobTitles);
            publishers.push({
                username: faker.internet.username() + '_' + faker.string.numeric(4),
                email: faker.internet.email(),
                password: defaultPassword,
                role: 'publisher',
                displayName: faker.person.fullName(),
                bio: `Author and ${job}. Writing about systems and design.`,
                profilePicture: `https://i.pravatar.cc/150?u=${faker.string.uuid()}`
            });
        }
        const createdPublishers = await User.insertMany(publishers);
        console.log(`Successfully created ${createdPublishers.length} publisher users.`);

        console.log('Generating 25 Professional Handbooks & Design Guides...');
        const books = [];
        
        for (let i = 0; i < createdPublishers.length; i++) {
            const user = createdPublishers[i];
            const title = professionalBookTitles[i % professionalBookTitles.length] + (i >= professionalBookTitles.length ? ` Vol. ${Math.floor(i / professionalBookTitles.length) + 1}` : '');
            const theme = imageThemes[i % imageThemes.length];
            const price = i < 18 ? 0 : parseFloat(faker.commerce.price({ min: 10, max: 99 }));
            
            let contentParts = [];
            for (let j = 0; j < 3; j++) {
                const rawText = faker.lorem.paragraphs(5);
                const paragraphChunk = `<p>${rawText.split('\n').join('</p><p>')}</p>`;
                
                const imageUrl = `https://picsum.photos/seed/${faker.string.uuid()}/800/600`;
                const imageChunk = `<div style="text-align:center; margin-bottom: 30px;"><img src="${imageUrl}" alt="${theme} illustration" style="max-width:100%; height:auto; border-radius:12px; box-shadow:0 10px 30px rgba(0,0,0,0.15); display:block; margin:0 auto;"></div>`;
                contentParts.push(imageChunk + paragraphChunk);
            }
            const content = contentParts.join('\n<hr>\n');
            const coverImageUrl = `https://picsum.photos/seed/${faker.string.uuid()}/400/600`;

            books.push({
                title: title,
                author: user._id,
                penName: user.displayName,
                description: `${title} is a comprehensive guide to mastering modern workflows. \n\n${faker.lorem.paragraphs(1)}`,
                coverImage: coverImageUrl,
                category: faker.helpers.arrayElement(categories), 
                price: price,
                content: content,
                isPublished: true,
                createdAt: faker.date.past({ years: 1 })
            });
        }
        await Book.insertMany(books);
        console.log(`Successfully created ${books.length} actual technical books and guides.`);

        console.log('Seed completed successfully! You can log in as any of these realistic users with password: password123');
        return true;

    } catch (err) {
        console.error('Seed error:', err);
        throw err;
    }
}

if (require.main === module) {
    seedDB()
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
} else {
    module.exports = seedDB;
}

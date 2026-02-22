const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
require('dotenv').config();

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/everything_spread';

async function generateTestUser() {
    try {
        await mongoose.connect(MONGO_URI);
        console.log('MongoDB Connected');

        const hashedPassword = await bcrypt.hash('password123', 10);

        let testUser = await User.findOne({ username: 'qatestuser' });

        if (testUser) {
            console.log('QA Test user already exists, resetting to clean state...');
            await testUser.deleteOne();
        }

        const newUser = new User({
            username: 'qatestuser',
            email: 'qa@test.com',
            password: hashedPassword,
            role: 'publisher',
            displayName: 'QA Automation',
            bio: 'Head of Quality Control. Following all the top spreaders.',
            isVerified: true // Bypass OTP requirement completely
        });

        await newUser.save();
        console.log('Successfully created testing user `qatestuser` with password `password123`.');

        process.exit(0);
    } catch (e) {
        console.error('Error generating test user:', e);
        process.exit(1);
    }
}

generateTestUser();

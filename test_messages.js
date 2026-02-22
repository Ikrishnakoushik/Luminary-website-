const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const User = require('./models/User');
const Message = require('./models/Message');

const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_key_here';
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/everything_spread';

async function testMessages() {
    await mongoose.connect(MONGO_URI);
    console.log("Connected to Mongo");

    const users = await User.find().limit(2);
    if (users.length < 2) {
        console.log("Need at least 2 users");
        process.exit(0);
    }

    const u1 = users[0];
    const u2 = users[1];

    console.log(`Using: ${u1.username} and ${u2.username}`);

    const newMsg = new Message({
        sender: u1._id,
        receiver: u2._id,
        content: "Test Message!"
    });
    await newMsg.save();
    console.log("Message saved!");

    const msgs = await Message.find().populate('sender').populate('receiver');
    console.log("Messages found:", msgs.length);
    process.exit(0);
}
testMessages();

const http = require('http');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const MessageAttachment = require('../models/MessageAttachment');

async function runTest() {
    console.log('--- Testing MessageAttachment Fallback and Serving ---');
    
    // Connect to Mongo
    const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/vylithra';
    await mongoose.connect(MONGO_URI);
    console.log('MongoDB connected.');

    // 1. Create a dummy binary image buffer
    const dummyImageBuffer = Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]); // JPEG header
    const testFilename = `test_photo_${Date.now()}.jpg`;

    // 2. Save directly as MessageAttachment (simulating upload fallback)
    const attachment = await MessageAttachment.create({
        filename: testFilename,
        contentType: 'image/jpeg',
        data: dummyImageBuffer,
        size: dummyImageBuffer.length
    });

    console.log('Attachment saved in MongoDB with ID:', attachment._id.toString());

    // 3. Retrieve attachment by ID
    const retrieved = await MessageAttachment.findById(attachment._id);
    if (!retrieved) {
        throw new Error('Failed to retrieve attachment from MongoDB');
    }
    if (retrieved.data.length !== dummyImageBuffer.length) {
        throw new Error(`Buffer length mismatch: expected ${dummyImageBuffer.length}, got ${retrieved.data.length}`);
    }
    if (retrieved.contentType !== 'image/jpeg') {
        throw new Error(`Content type mismatch: expected image/jpeg, got ${retrieved.contentType}`);
    }

    console.log('Attachment retrieval and verification SUCCESSFUL!');

    // Clean up test document
    await MessageAttachment.deleteOne({ _id: attachment._id });
    console.log('Test cleanup complete.');
    
    await mongoose.disconnect();
    console.log('--- ALL TESTS PASSED ---');
    process.exit(0);
}

runTest().catch(err => {
    console.error('Test FAILED:', err);
    process.exit(1);
});

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
if (!uri) {
    console.error('MONGO_URI is missing from environment variables (.env).');
    process.exit(1);
}

mongoose.connect(uri).then(async () => {
    const db = mongoose.connection.db;
    const targetEmail = process.env.ADMIN_EMAIL || 'ikowshikreddy800@gmail.com';
    const newPass = process.argv[2] || process.env.NEW_PASSWORD;
    if (!newPass) {
        console.error('Usage: node updatePass.js <new_password>');
        process.exit(1);
    }
    const hash = await bcrypt.hash(newPass, 10);
    await db.collection('users').updateOne({ email: targetEmail }, { $set: { password: hash } });
    console.log('Password updated successfully!');
    process.exit(0);
}).catch(err => {
    console.error('Failed to update password:', err.message);
    process.exit(1);
});

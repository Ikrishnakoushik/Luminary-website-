const mongoose = require('mongoose');

const uri = "mongodb://Ikrishna:project3@ac-egvdm9p-shard-00-00.kj3z6.mongodb.net:27017/everything_spread?ssl=true&authSource=admin";

console.log("Testing connection...");

// Set timeout to 5 seconds
setTimeout(() => {
    console.error("TIMEOUT: Connection took too long. Local network likely blocked.");
    process.exit(1);
}, 5000);

mongoose.connect(uri)
    .then(() => {
        console.log("SUCCESS: Connection established!");
        process.exit(0);
    })
    .catch(err => {
        console.error("FAILURE:", err.message);
        process.exit(1);
    });

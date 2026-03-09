const http = require('http');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'your_jwt_secret_key_here';

async function test() {
    const token = jwt.sign(
        { user: { id: "69adb19bb4fcddc89281fb63" } },
        JWT_SECRET,
        { expiresIn: "5h" }
    );

    // Test the purchase intent API
    console.log("=== Testing POST /api/books/:id/purchase-intent ===");
    try {
        const res = await fetch('http://localhost:3000/api/books/69a9b39cc90f47ec11109520/purchase-intent', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-auth-token': token
            },
            body: JSON.stringify({ gateway: 'razorpay' })
        });

        console.log(`Status: ${res.status}`);
        const text = await res.text();
        console.log(`Response: ${text.substring(0, 100)}`);
    } catch (e) {
        console.error("-> FETCH THREW:", e.message);
    }
}

test();

const http = require('http');

const email = `test_enforce_${Date.now()}@example.com`;
const password = 'password123';

function request(options, data) {
    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => resolve({ statusCode: res.statusCode, body: JSON.parse(body || '{}') }));
        });
        req.on('error', reject);
        if (data) req.write(JSON.stringify(data));
        req.end();
    });
}

async function run() {
    console.log('1. Registering user:', email);
    const regRes = await request({
        hostname: 'localhost', port: 3000, path: '/api/register', method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    }, { username: 'enforce_' + Date.now(), email, password, role: 'reader' });

    console.log('Register Response:', regRes.statusCode, regRes.body);

    if (regRes.statusCode === 201 && regRes.body.msg.includes('Verification required')) {
        console.log('PASS: Registration triggers verification step.');
    } else {
        console.log('FAIL: Registration did not prompt for verification.');
    }

    console.log('\n2. Attempting Login (Unverified)...');
    const loginRes = await request({
        hostname: 'localhost', port: 3000, path: '/api/login', method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    }, { email, password });

    console.log('Login Response:', loginRes.statusCode, loginRes.body);

    if (loginRes.statusCode === 400 && loginRes.body.msg.includes('Please verify')) {
        console.log('PASS: Login blocked for unverified user.');
    } else {
        console.log('FAIL: Login allowed or wrong error message.');
    }
}

run();

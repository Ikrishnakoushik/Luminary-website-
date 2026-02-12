const http = require('http');
const fs = require('fs');

const email = `test_verify_${Date.now()}@example.com`;
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
    }, { username: 'ver_user_' + Date.now(), email, password, role: 'reader' });

    console.log('Register Response:', regRes.statusCode, regRes.body);

    if (regRes.statusCode !== 201) return;

    console.log('2. Reading server log for OTP...');
    // Allow time for log write
    await new Promise(r => setTimeout(r, 2000));

    const logContent = fs.readFileSync('server_verify.log', 'utf8');
    const match = logContent.match(/Verification OTP for .*?: (\d{6})/);

    if (!match) {
        console.error('OTP not found in log!');
        return;
    }
    const otp = match[1];
    console.log('Found OTP:', otp);

    console.log('3. Verifying Email...');
    const verRes = await request({
        hostname: 'localhost', port: 3000, path: '/api/verify-email', method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    }, { email, otp });

    console.log('Verify Response:', verRes.statusCode, verRes.body);

    if (verRes.statusCode === 200 && verRes.body.token) {
        console.log('SUCCESS: Email verified and token received!');
    } else {
        console.error('FAILURE: Verification failed.');
    }
}

run();

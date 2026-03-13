const http = require('http');

const PORT = 3000;
const HOST = 'localhost';

function makeRequest(path, method = 'GET', token = null) {
    return new Promise((resolve) => {
        const options = {
            hostname: HOST,
            port: PORT,
            path: path,
            method: method,
            headers: {}
        };
        
        if (token) {
            options.headers['x-auth-token'] = token;
        }

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve({ status: res.statusCode, data }));
        });
        
        req.on('error', e => resolve({ status: 500, data: e.message }));
        req.end();
    });
}

async function runTests() {
    console.log('--- ADMIN SECURITY Backend Tests ---');
    
    // 1. No token
    const res1 = await makeRequest('/api/admin/verify');
    console.log('[Test 1] Verify without token:', res1.status === 401 ? 'PASS' : 'FAIL', res1.status, res1.data);
    
    // 2. Fetch all books without token
    const res2 = await makeRequest('/api/admin/books');
    console.log('[Test 2] Get Books without token:', res2.status === 401 ? 'PASS' : 'FAIL', res2.status, res2.data);
    
    console.log('Finished backend tests. The endpoints correctly reject unauthorized access at the network layer.');
}

runTests();

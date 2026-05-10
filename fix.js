const fs = require('fs');
let content = fs.readFileSync('public/auth.html', 'utf8');

const startMarker = "const API_URL = window.location.hostname === 'localhost' ? 'http://localhost:3000/api' : '/api';";
const endMarker = "// 2FA Submit";

const startIndex = content.indexOf(startMarker);
const endIndex = content.indexOf(endMarker);

if (startIndex === -1 || endIndex === -1) {
    console.error('Markers not found');
    process.exit(1);
}

const newCode = `const API_URL = window.location.hostname === 'localhost' ? 'http://localhost:3000/api' : '/api';

        let pendingLoginEmail = '';
        let pendingLoginPassword = '';

        // Handle Login
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('loginEmail').value;
            const password = document.getElementById('loginPassword').value;
            const errorMsg = document.getElementById('loginError');
            errorMsg.innerText = '';

            const submitBtn = e.target.querySelector('button[type="submit"]');
            const originalText = submitBtn.innerText;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i> Authenticating...';
            submitBtn.disabled = true;

            try {
                const res = await fetch(\`\${API_URL}/login\`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });
                
                const data = await res.json();
                
                if (res.ok) {
                    if (data.requires2FA) {
                        pendingLoginEmail = email;
                        pendingLoginPassword = password;
                        switchTab('twofa');
                    } else {
                        localStorage.setItem('token', data.token);
                        localStorage.setItem('role', data.role);
                        localStorage.setItem('user', JSON.stringify(data.user));
                        window.location.href = '/main';
                    }
                } else {
                    if (data.requiresVerification) {
                        pendingLoginEmail = email;
                        document.getElementById('verifyEmailDisplay').innerText = email;
                        switchTab('verify');
                    } else {
                        errorMsg.innerText = data.msg || 'Invalid email or password.';
                    }
                }
            } catch (err) {
                console.error(err);
                errorMsg.innerText = 'Authentication error or server is down.';
            } finally {
                submitBtn.innerHTML = originalText;
                submitBtn.disabled = false;
            }
        });

        // Handle Registration
        document.getElementById('registerForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const displayName = document.getElementById('regUsername').value;
            const email = document.getElementById('regEmail').value;
            const password = document.getElementById('regPassword').value;
            const role = document.getElementById('regRole').value;
            const errorMsg = document.getElementById('regError');
            errorMsg.innerText = '';

            const submitBtn = e.target.querySelector('button[type="submit"]');
            const originalText = submitBtn.innerText;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i> Creating account...';
            submitBtn.disabled = true;

            try {
                const res = await fetch(\`\${API_URL}/register\`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password, displayName, role })
                });

                const data = await res.json();
                
                if (res.ok) {
                    pendingLoginEmail = email;
                    document.getElementById('verifyEmailDisplay').innerText = email;
                    switchTab('verify');
                } else {
                    errorMsg.innerText = data.msg || 'Registration failed';
                }
            } catch (err) {
                console.error(err);
                errorMsg.innerText = 'Registration error or server is down.';
            } finally {
                submitBtn.innerHTML = originalText;
                submitBtn.disabled = false;
            }
        });

        // Verify Email Submit
        document.getElementById('verifyForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const otpCode = document.getElementById('verifyOtp').value;
            const errorMsg = document.getElementById('verifyError');
            errorMsg.innerText = '';
            
            const submitBtn = e.target.querySelector('button[type="submit"]');
            const originalText = submitBtn.innerText;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i> Verifying...';
            submitBtn.disabled = true;

            try {
                const res = await fetch(\`\${API_URL}/verify-email\`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: pendingLoginEmail, otp: otpCode })
                });
                const data = await res.json();

                if (res.ok) {
                    localStorage.setItem('token', data.token);
                    localStorage.setItem('role', data.role);
                    localStorage.setItem('user', JSON.stringify(data.user));
                    window.location.href = '/main';
                } else {
                    errorMsg.innerText = data.msg || 'Invalid code.';
                }
            } catch (err) {
                console.error(err);
                errorMsg.innerText = 'Oops! Our servers took a quick nap. Please try again.';
            } finally {
                submitBtn.innerHTML = originalText;
                submitBtn.disabled = false;
            }
        });

        `;

content = content.substring(0, startIndex) + newCode + content.substring(endIndex);
fs.writeFileSync('public/auth.html', content);
console.log('SUCCESS');

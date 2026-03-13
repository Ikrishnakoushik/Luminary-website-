const fs = require('fs');

const path = 'c:/Users/Illuri/OneDrive/Desktop/project3/public/vylithra-admin-portal.html';
let html = fs.readFileSync(path, 'utf8');

// 1. Replace verifyAdmin and buildDashboardUI to insert the Gateway Challenge
const verifyAdminRegex = /async function verifyAdmin\(\) \{[\s\S]*?function buildDashboardUI\(user\) \{/m;

const gatewayReplacement = `
        async function verifyAdmin() {
            try {
                const response = await fetch('/api/admin/verify', {
                    headers: { 'x-auth-token': token }
                });

                if (response.ok) {
                    const data = await response.json();
                    document.title = 'Secure Gateway | Admin';
                    showGatewayChallenge(data.user);
                } else {
                    console.warn('Unauthorized. Ejecting.');
                    window.location.replace('/main');
                }
            } catch (error) {
                console.error('System error:', error);
                window.location.replace('/main');
            }
        }

        function showGatewayChallenge(user) {
            document.getElementById('hollow-state').style.display = 'none';
            const dashboard = document.getElementById('admin-dashboard');
            dashboard.style.display = 'flex';
            dashboard.style.alignItems = 'center';
            dashboard.style.justifyContent = 'center';
            dashboard.style.minHeight = '100vh';
            dashboard.style.background = 'var(--bg-light)';
            
            dashboard.innerHTML = \`
                <div style="background: white; padding: 3rem 2rem; border-radius: 1rem; box-shadow: 0 10px 30px rgba(0,0,0,0.05); text-align: center; max-width: 400px; width: 100%;">
                    <i class="fas fa-shield-alt" style="font-size: 3rem; color: var(--primary); margin-bottom: 1.5rem;"></i>
                    <h2 style="margin: 0 0 0.5rem 0;">Security Gateway</h2>
                    <p style="color: var(--text-muted); margin-bottom: 2rem; font-size: 0.875rem;">Enter Master Credentials to unlock the Command Center.</p>
                    
                    <div style="text-align: left; margin-bottom: 1rem;">
                        <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.5rem;">Master Email</label>
                        <input type="email" id="gateway-email" placeholder="admin@example.com" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border); border-radius: 0.5rem; outline: none; font-size: 1rem; box-sizing: border-box;">
                    </div>
                    
                    <div style="text-align: left; margin-bottom: 2rem;">
                        <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.5rem;">Master Secret Key</label>
                        <input type="password" id="gateway-key" placeholder="••••••••••••••••" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border); border-radius: 0.5rem; outline: none; font-size: 1rem; box-sizing: border-box;">
                    </div>
                    
                    <button onclick="unlockAdmin('\${user.username}')" style="width: 100%; padding: 0.875rem; background: var(--primary); color: white; border: none; border-radius: 0.5rem; font-weight: 600; cursor: pointer; font-size: 1rem; transition: 0.2s;">
                        Unlock System <i class="fas fa-unlock" style="margin-left: 0.5rem;"></i>
                    </button>
                    <p id="gateway-error" style="color: var(--danger); font-size: 0.875rem; margin-top: 1rem; display: none;">Invalid credentials.</p>
                </div>
            \`;
            
            // Allow pressing Enter
            document.getElementById('gateway-key').addEventListener('keypress', function (e) {
                if (e.key === 'Enter') unlockAdmin(user.username);
            });
        }

        async function unlockAdmin(username) {
            const email = document.getElementById('gateway-email').value;
            const secretKey = document.getElementById('gateway-key').value;
            const errorMsg = document.getElementById('gateway-error');
            
            errorMsg.style.display = 'none';
            
            try {
                const res = await fetch('/api/admin/gateway', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'x-auth-token': token },
                    body: JSON.stringify({ email, secretKey })
                });
                
                if (res.ok) {
                    const data = await res.json();
                    sessionStorage.setItem('gatewayToken', data.token); // Store secure token
                    buildDashboardUI({ username }); // Proceed to dashboard
                } else {
                    errorMsg.style.display = 'block';
                }
            } catch (e) {
                console.error(e);
                errorMsg.innerText = 'Network error contacting security terminal.';
                errorMsg.style.display = 'block';
            }
        }

        function getAuthHeaders() {
            return {
                'Content-Type': 'application/json',
                'x-auth-token': token,
                'x-gateway-token': sessionStorage.getItem('gatewayToken')
            };
        }

        function buildDashboardUI(user) {`;

html = html.replace(verifyAdminRegex, gatewayReplacement);

// 2. Add styles for FontAwesome in the head if not present
if (!html.includes('cdnjs.cloudflare.com/ajax/libs/font-awesome')) {
    html = html.replace('</head>', '    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">\n</head>');
}

// 3. Make the dashboard container revert to block if it was changed to flex
html = html.replace('dashboard.style.display = \'block\';', 'dashboard.style.display = \'block\';\n            dashboard.style.alignItems = \'initial\';\n            dashboard.style.justifyContent = \'initial\';\n            dashboard.style.minHeight = \'initial\';\n            dashboard.style.background = \'var(--bg-light)\';');

// 4. Update all fetch headers natively to use getAuthHeaders()
// Exception for /api/admin/verify and /api/admin/setup-first-admin and /api/admin/gateway
const fetchRegex = /headers:\s*\{\s*['"]x-auth-token['"]:\s*token\s*\}/g;
html = html.replace(fetchRegex, "headers: { 'x-auth-token': token, 'x-gateway-token': sessionStorage.getItem('gatewayToken') }");

const fetchWithJsonRegex = /headers:\s*\{\s*['"]Content-Type['"]:\s*['"]application\/json['"],\s*['"]x-auth-token['"]:\s*token\s*\}/g;
html = html.replace(fetchWithJsonRegex, "headers: getAuthHeaders()");

fs.writeFileSync(path, html, 'utf8');
console.log('Successfully injected Gateway into vylithra-admin-portal.html');

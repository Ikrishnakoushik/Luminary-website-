const fs = require('fs');

let data = fs.readFileSync('server.js', 'utf8');

// 1. Add WAF Middleware
data = data.replace(
    'app.use(express.urlencoded({ extended: true })); // Ensure bodies are parsed',
    `app.use(express.urlencoded({ extended: true })); // Ensure bodies are parsed

// Advanced Web Application Firewall (WAF)
const { wafMiddleware, addThreatScore } = require('./middleware/waf');
app.use(wafMiddleware);

// WAF Honeypot Endpoint
app.all('/api/admin/hidden-debug-endpoint', async (req, res) => {
    const ip = req.headers['x-forwarded-for'] || req.ip || req.connection.remoteAddress;
    await addThreatScore(ip, 150, 'Triggered Honeypot Trap');
    res.status(403).json({ msg: 'Forbidden' });
});`
);

// 2. Fix the Sitemap bug
data = data.replace(
    `const books = await Book.find({ status: 'published' }).select('_id updatedAt');`,
    `const books = await Book.find({ isPublished: true }).select('_id updatedAt');`
);

// 3. Update the Admin Settings API to handle WAF
data = data.replace(
    `            settings.downloadFeePercentage = downloadFeePercentage !== undefined ? downloadFeePercentage : settings.downloadFeePercentage;
            
            await settings.save();`,
    `            settings.downloadFeePercentage = downloadFeePercentage !== undefined ? downloadFeePercentage : settings.downloadFeePercentage;
            
            if (req.body.firewallEnabled !== undefined) settings.firewallEnabled = req.body.firewallEnabled;
            if (req.body.firewallStrictness !== undefined) settings.firewallStrictness = req.body.firewallStrictness;

            await settings.save();`
);

// 4. Add the Unban route
data = data.replace(
    `// 7. User Management (Get All)`,
    `// --- WAF Unban Route ---
app.post('/api/admin/firewall/unban', adminAuth, async (req, res) => {
    try {
        const { ip } = req.body;
        if (!ip) return res.status(400).json({ msg: 'IP address is required' });

        let settings = await PlatformSetting.findOne();
        if (settings && settings.ipBlacklist) {
            settings.ipBlacklist = settings.ipBlacklist.filter(b => b.ip !== ip);
            await settings.save();
        }
        res.json({ msg: \`IP \${ip} has been unbanned.\`, ipBlacklist: settings ? settings.ipBlacklist : [] });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 7. User Management (Get All)`
);

fs.writeFileSync('server.js', data);
console.log('Patch complete.');

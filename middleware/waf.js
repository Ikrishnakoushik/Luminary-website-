const PlatformSetting = require('../models/PlatformSetting');

// In-memory threat tracker: Map<IP, { score: Number, expires: Date }>
const threatTracker = new Map();

// Configuration
const THREAT_THRESHOLD = 100;
const THREAT_DECAY_MS = 60 * 60 * 1000; // 1 hour decay
const BAN_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours ban

// ==========================================
// 1. ADVANCED OWASP SIGNATURE DATABASES
// ==========================================
const OWASP_SIGNATURES = {
    // Advanced SQL Injection (Error, Boolean, Time, UNION based)
    sqli: new RegExp([
        '(?:\\b(?:update|delete|insert|drop|truncate|alter|create|rename|desc)\\b.*\\s+.*\\b(?:from|into|table|database)\\b)',
        '(?:\\b(?:union|intersect|except)\\b.*\\b(?:all|select)\\b)',
        '(?:\\b(?:select)\\b.*\\b(?:from)\\b.*(?:where|limit|order by|group by))',
        '(?:\\b(?:exec|execute|sp_executesql)\\b)',
        '(?:\\b(?:information_schema|mysql\\.|pg_catalog|sys\\.)\\b)',
        '(?:\\b(?:waitfor\\s+delay|sleep|benchmark|pg_sleep)\\b)',
        '(?:--|#|\\/\\*)',
        '(?:\\b(?:OR|AND)\\b\\s+[\'"]?[\\w\\d]+[\'"]?\\s*=\\s*[\'"]?[\\w\\d]+[\'"]?)' // 1=1 boolean based
    ].join('|'), 'i'),

    // Advanced Cross-Site Scripting (XSS)
    xss: new RegExp([
        '(?:<\\s*(?:script|iframe|object|embed|applet|meta|form|svg|math|base|style))',
        '(?:\\b(?:javascript|vbscript|livescript|data):)',
        '(?:\\b(?:on(?:load|error|mouseover|click|focus|blur|keydown|keyup|submit|reset|select|change))\\s*=)',
        '(?:\\b(?:eval|setTimeout|setInterval|Function|execScript|crypto\\.generateCRMFRequest)\\s*\\()',
        '(?:document\\.(?:cookie|location|write|URL|documentURI))',
        '(?:window\\.(?:name|location|href))'
    ].join('|'), 'i'),

    // Local File Inclusion (LFI) & Path Traversal
    lfi: new RegExp([
        '(?:\\.\\.\\/|\\.\\.\\\\|%2e%2e%2f|%2e%2e%5c|%252e%252e%252f)',
        '(?:\\b(?:etc\\/passwd|windows\\\\system32|boot\\.ini|shadow|hosts)\\b)',
        '(?:\\b(?:file|php|zlib|data|glob|phar|ssh2|rar|ogg|expect):\\/\\/)'
    ].join('|'), 'i'),

    // Remote Code Execution (RCE) / Command Injection
    rce: new RegExp([
        '(?:\\b(?:shell_exec|system|passthru|proc_open|popen|exec)\\s*\\()',
        '(?:(?:\\||;|&&|\\|\\|)\\s*(?:bash|sh|cmd|powershell|python|perl|ruby|php|nc|netcat|wget|curl|ping|nslookup|dig)\\b)',
        '(?:\\/bin\\/(?:bash|sh|zsh|dash))'
    ].join('|'), 'i')
};

// ==========================================
// 2. KNOWN MALICIOUS USER AGENTS (BOTS & SCANNERS)
// ==========================================
const MALICIOUS_BOTS = new RegExp([
    '(?:sqlmap|nikto|dirbuster|nmap|zmap|masscan|hydra|medusa)',
    '(?:arachni|w3af|acunetix|netsparker|appscan|nessus|openvas)',
    '(?:burpsuite|postman|insomnia|curl\\/|wget\\/|libwww-perl|python-requests|go-http-client)', // Note: Adjust if API explicitly requires curl/postman
    '(?:zgrab|censys|shodan|masscan)'
].join('|'), 'i');

// ==========================================
// 3. NORMALIZATION & PRE-PROCESSING
// ==========================================
// Attackers use encoding tricks. We must normalize the string before testing regex.
const normalizePayload = (val) => {
    if (typeof val !== 'string') return '';
    let normalized = val;

    try {
        // Repeatedly decode until fully decoded to catch multiple encoding evasion (e.g. %253Cscript%253E)
        let previous = '';
        let iterations = 0;
        while (normalized !== previous && iterations < 5) {
            previous = normalized;
            normalized = decodeURIComponent(normalized.replace(/\\x/g, '%')); // Handle \x encoding too
            iterations++;
        }
    } catch (e) {
        // If decoding fails (malformed URI), it's highly suspicious. We treat the raw string.
    }

    // Strip Null Bytes (C-style string evasion)
    normalized = normalized.replace(/\0/g, '');
    
    // Collapse excess whitespace
    normalized = normalized.replace(/\s+/g, ' ');

    return normalized;
};

// Recursive function to deeply inspect payload objects (body, query) and handle HTTP Parameter Pollution (HPP) Arrays
const inspectPayloadDeep = (payload, strictness) => {
    let triggered = null;

    const checkValue = (val) => {
        if (typeof val === 'string') {
            const normalized = normalizePayload(val);
            for (const [type, regex] of Object.entries(OWASP_SIGNATURES)) {
                if (regex.test(normalized)) {
                    // For Paranoid mode, ANY match is a hit. For high, we skip minor false positives if needed.
                    if (strictness === 'high' && type === 'sqli' && /select/i.test(normalized) && !/union|drop|from/i.test(normalized)) {
                         // Extremely common false positive (e.g. "please select a date") - skip if just 'select'
                         continue; 
                    }
                    triggered = type;
                    return true;
                }
            }
        } else if (Array.isArray(val)) {
            // HPP Prevention: Express parses ?id=1&id=2 as an array. 
            // We inspect each element. 
            for (let i = 0; i < val.length; i++) {
                if (checkValue(val[i])) return true;
            }
        } else if (typeof val === 'object' && val !== null) {
            for (const key in val) {
                // Inspect keys too (attackers can put payloads in JSON keys)
                if (checkValue(key)) return true;
                if (checkValue(val[key])) return true;
            }
        }
        return false;
    };

    checkValue(payload);
    return triggered;
};

// ==========================================
// 4. CORE ENGINE LOGIC
// ==========================================

const addThreatScore = async (ip, score, reason) => {
    const now = Date.now();
    let record = threatTracker.get(ip);
    
    if (!record || record.expires < now) {
        record = { score: 0, expires: now + THREAT_DECAY_MS };
    }

    record.score += score;
    record.expires = now + THREAT_DECAY_MS;
    threatTracker.set(ip, record);

    console.log(`[WAF] IP ${ip} gained +${score} threat score (${reason}). Total: ${record.score}`);

    if (record.score >= THREAT_THRESHOLD) {
        await banIp(ip, `Auto-banned: Exceeded threat threshold (${reason})`);
        threatTracker.delete(ip);
    }
};

const banIp = async (ip, reason) => {
    try {
        let settings = await PlatformSetting.findOne();
        if (!settings) settings = new PlatformSetting();

        const alreadyBanned = settings.ipBlacklist.find(b => b.ip === ip);
        if (!alreadyBanned) {
            settings.ipBlacklist.push({
                ip,
                reason,
                bannedAt: new Date(),
                expiresAt: new Date(Date.now() + BAN_DURATION_MS)
            });
            await settings.save();
            console.warn(`[WAF] 🚨 SECURITY ALERT: IP ${ip} has been BANNED. Reason: ${reason}`);
        }
    } catch (err) {
        console.error('[WAF Error] Failed to ban IP:', err);
    }
};

// The Middleware
const wafMiddleware = async (req, res, next) => {
    const ip = req.headers['x-forwarded-for'] || req.ip || req.connection.remoteAddress;

    try {
        let settings = await PlatformSetting.findOne();
        if (!settings || !settings.firewallEnabled) {
            return next();
        }

        // 1. IP Whitelist Bypass
        if (settings.ipWhitelist && settings.ipWhitelist.includes(ip)) {
            return next();
        }

        // 2. IP Blacklist Enforcement
        const blacklistEntry = settings.ipBlacklist.find(b => b.ip === ip);
        if (blacklistEntry) {
            if (blacklistEntry.expiresAt && blacklistEntry.expiresAt < new Date()) {
                settings.ipBlacklist = settings.ipBlacklist.filter(b => b.ip !== ip);
                await settings.save();
            } else {
                return res.status(403).send(`
                    <html>
                    <head><title>Access Denied</title></head>
                    <body style="background:#000;color:#f00;font-family:monospace;text-align:center;padding:50px;">
                        <h1>[WAF] 403 FORBIDDEN</h1>
                        <p>Connection Terminated.</p>
                        <p>Origin: ${ip}</p>
                        <p>Violation: ${blacklistEntry.reason || 'Enterprise WAF Rule Triggered'}</p>
                    </body>
                    </html>
                `);
            }
        }

        const strictness = settings.firewallStrictness || 'high';

        if (strictness !== 'low') {
            // 3. User-Agent Bot Detection
            const userAgent = req.headers['user-agent'] || '';
            // Only block API tools if they are not explicitly whitelisted by the frontend or if it's strict
            // We'll skip blocking generic curl/postman unless in paranoid mode to avoid dev annoyance, but block scanners.
            if (MALICIOUS_BOTS.test(userAgent)) {
                if (strictness === 'paranoid' || !/(curl|postman|insomnia|python)/i.test(userAgent)) {
                    await addThreatScore(ip, 200, `Malicious User-Agent Detected (${userAgent})`);
                    return res.status(403).json({ error: "WAF_BLOCK", code: 1001, msg: "Request blocked by Enterprise WAF: Malicious Scanner Detected." });
                }
            }

            // 4. Payload Inspection (Body, Query, Params, Headers)
            const bodyThreat = inspectPayloadDeep(req.body, strictness);
            const queryThreat = inspectPayloadDeep(req.query, strictness);
            const paramsThreat = inspectPayloadDeep(req.params, strictness);
            
            // Inspect certain critical headers for injection (e.g. Host, Referer)
            const headerThreat = inspectPayloadDeep({ 
                referer: req.headers['referer'], 
                host: req.headers['host'],
                cookie: req.headers['cookie']
            }, strictness);

            const threat = bodyThreat || queryThreat || paramsThreat || headerThreat;
            
            if (threat) {
                let penalty = (strictness === 'paranoid') ? 150 : 100;
                await addThreatScore(ip, penalty, `OWASP Core Rule Set Triggered: ${threat.toUpperCase()}`);
                return res.status(400).json({ error: "WAF_BLOCK", code: 2001, msg: "Request blocked by Enterprise WAF: Malicious Payload Signature." });
            }
        }

        req.clientIp = ip;
        next();
    } catch (error) {
        console.error('[WAF] Middleware Critical Error:', error);
        next(); // Fail open to prevent platform outage
    }
};

module.exports = {
    wafMiddleware,
    addThreatScore,
    banIp
};

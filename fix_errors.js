const fs = require('fs');
const path = require('path');

const serverPath = path.join(__dirname, 'server.js');
let code = fs.readFileSync(serverPath, 'utf8');

const friendlyError = "Oops! Our servers took a quick nap. Please try again.";

// Replace various generic error messages with the friendly one
code = code.replace(/res\.status\(500\)\.send\('Server Error'\)/g, `res.status(500).send('${friendlyError}')`);
code = code.replace(/res\.status\(500\)\.json\(\{\s*msg:\s*'Server Error'\s*\}\)/g, `res.status(500).json({ msg: '${friendlyError}' })`);
code = code.replace(/res\.status\(500\)\.json\(\{\s*msg:\s*'Server error'\s*\}\)/g, `res.status(500).json({ msg: '${friendlyError}' })`);
code = code.replace(/res\.status\(500\)\.send\('Something broke!'\)/g, `res.status(500).send('${friendlyError}')`);

fs.writeFileSync(serverPath, code);
console.log('Successfully updated error messages in server.js');

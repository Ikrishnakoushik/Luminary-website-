const fs = require('fs');
const path = require('path');

const htmlFile = 'c:/Users/Illuri/OneDrive/Desktop/project3/public/vylithra-admin-portal.html';
const pkgFile = 'c:/Users/Illuri/OneDrive/Desktop/project3/package.json';

try {
    let htmlContent = fs.readFileSync(htmlFile, 'utf8');
    
    // Remove the backslash before backticks and dollar curly braces
    htmlContent = htmlContent.split('\\`').join('`');
    htmlContent = htmlContent.split('\\${').join('${');
    
    fs.writeFileSync(htmlFile, htmlContent, 'utf8');
    console.log('Fixed syntax errors in vylithra-admin-portal.html');
} catch (e) {
    console.error('Failed to fix HTML file:', e);
}

try {
    let pkgContent = fs.readFileSync(pkgFile, 'utf8');
    
    // Fix capitalized name to satisfy npm restrictions
    pkgContent = pkgContent.replace('"name": "Vylithra"', '"name": "vylithra"');
    
    fs.writeFileSync(pkgFile, pkgContent, 'utf8');
    console.log('Fixed package.json name warning');
} catch (e) {
    console.error('Failed to fix package.json:', e);
}

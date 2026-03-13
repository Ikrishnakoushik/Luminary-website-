const fs = require('fs');
const path = require('path');

const publicDir = path.join(__dirname, 'public');

function processDirectory(dir) {
    const files = fs.readdirSync(dir);
    
    files.forEach(file => {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            processDirectory(fullPath);
        } else if (fullPath.endsWith('.html') || fullPath.endsWith('.js')) {
            let content = fs.readFileSync(fullPath, 'utf8');
            let originalContent = content;
            
            // Matches href="somepage.html" or "somepage.html?x=y"
            content = content.replace(/href=(["'])(?!http)([^"']+?)\.html(\?[^"']*)?\1/g, 'href=$1$2$3$1');
            
            // Matches string bindings like window.location.href = "something.html"
            content = content.replace(/((?:window\.)?location(?:\.href|\.assign|\.replace)?\s*(?:=|[(])\s*)(["'])(?!http)([^"']+?)\.html(\?[^"']*)?\2/g, "$1$2$3$4$2");
            
            // Catch simple unassigned string references often found in template literals/fetches if any
            // We'll skip general string replacing to be safe, the two above handle almost 99% of navigation
            
            // Specific for vylithra-admin-portal routing where we did `if (tab === 'books') window.location.replace('/main.html')`
            content = content.replace(/replace\(['"]\/([a-zA-Z-]+)\.html['"]\)/g, "replace('/$1')");
            content = content.replace(/href\s*=\s*['"]\/([a-zA-Z-]+)\.html['"]/g, "href='/$1'");

            if (content !== originalContent) {
                fs.writeFileSync(fullPath, content, 'utf8');
                console.log(`Updated: ${file}`);
            }
        }
    });
}

processDirectory(publicDir);
console.log('Finished scrubbing .html from frontend links.');

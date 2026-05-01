const fs = require('fs');
const path = require('path');

const publicDir = path.join(__dirname, 'public');
const friendlyError = "Oops! Our servers took a quick nap. Please try again.";

const walkSync = (dir, filelist = []) => {
  fs.readdirSync(dir).forEach(file => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      filelist = walkSync(filePath, filelist);
    } else {
      if (filePath.endsWith('.html') || filePath.endsWith('.js')) {
         filelist.push(filePath);
      }
    }
  });
  return filelist;
}

const files = walkSync(publicDir);
let count = 0;
files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let originalContent = content;
  
  // Replace various patterns of 'Server error'
  content = content.replace(/Server error\. Please try again\./gi, friendlyError);
  content = content.replace(/Server error\./gi, friendlyError);
  content = content.replace(/'Server error'/gi, `'${friendlyError}'`);
  content = content.replace(/"Server error"/gi, `"${friendlyError}"`);
  
  if (content !== originalContent) {
    fs.writeFileSync(file, content);
    count++;
    console.log(`Updated: ${path.basename(file)}`);
  }
});

console.log(`Successfully updated ${count} frontend files.`);

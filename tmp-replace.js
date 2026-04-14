const fs = require('fs');

let mainHtml = fs.readFileSync('public/main.html', 'utf8');
const fetchPostsMatches = mainHtml.match(/async function fetchPosts\(\) {/g);
if (fetchPostsMatches && fetchPostsMatches.length > 1) {
    console.log("Found duplicate fetchPosts in main.html, removing second occurrence.");
    // split by the function declaration
    let parts = mainHtml.split(/async function fetchPosts\(\) {/);
    if(parts.length >= 3) {
        // Reconstruct: part 0 + 'async function fetchPosts() {' + part 1
        // We drop part 2 (the second declaration block)
        // But part 2 contains the rest of the file! So we just replace the second "async function fetchPosts() {" with "async function _fetchPostsDuplicate() {"
        mainHtml = parts[0] + 'async function fetchPosts() {' + parts[1] + 'async function _fetchPostsDuplicate() {' + parts.slice(2).join('async function fetchPosts() {');
        fs.writeFileSync('public/main.html', mainHtml);
    }
}

let reelsHtml = fs.readFileSync('public/reels.html', 'utf8');
const updateScrubberMatches = reelsHtml.match(/function updateScrubber\(/g);
if (updateScrubberMatches && updateScrubberMatches.length > 1) {
    console.log("Found duplicate updateScrubber in reels.html, renaming first occurrence.");
    let parts = reelsHtml.split('function updateScrubber(videoElement)');
    if (parts.length >= 2) {
        reelsHtml = parts[0] + 'function _updateScrubberOld(videoElement)' + parts.slice(1).join('function updateScrubber(videoElement)');
    }
    
    let parts2 = reelsHtml.split('function seekVideo(e, trackElement)');
    if (parts2.length >= 2) {
        reelsHtml = parts2[0] + 'function _seekVideoOld(e, trackElement)' + parts2.slice(1).join('function seekVideo(e, trackElement)');
    }
    fs.writeFileSync('public/reels.html', reelsHtml);
}

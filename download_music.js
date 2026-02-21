const https = require('https');
const fs = require('fs');

const url = 'https://cdn.pixabay.com/audio/2022/05/27/audio_1808fbf07a.mp3'; // Upbeat corporate
const dest = 'public/promo_music.mp3';

const file = fs.createWriteStream(dest);
https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, function (response) {
    response.pipe(file);
    file.on('finish', function () {
        file.close(() => console.log('Download complete.'));
    });
}).on('error', function (err) {
    fs.unlink(dest, () => { });
    console.error('Error downloading:', err.message);
});

const fs = require('fs');
let lines = fs.readFileSync('server.js', 'utf8').split('\n');

const replacement = `app.use('/api', async (req, res, next) => {
    await connectDB();
    next();
});

// Dynamic Sitemap Generation
app.get('/sitemap.xml', async (req, res) => {
    try {
        await connectDB();
        const HOST = 'https://vylithra.in';

        // Let's create the XML structure
        let xml = '<?xml version="1.0" encoding="UTF-8"?>\\n';
        xml += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\\n';

        // 1. Static Core Pages
        const staticPages = [
            '/', '/auth', '/main', '/studio', '/settings', '/community',
            '/books', '/creator-kit', '/publish-book', '/documentation',
            '/legal', '/messages', '/profile'
        ];

        staticPages.forEach(page => {
            xml += \`  <url>\\n    <loc>\${HOST}\${page}</loc>\\n    <changefreq>daily</changefreq>\\n    <priority>0.8</priority>\\n  </url>\\n\`;
        });

        // 2. Dynamic Books Pages
        const books = await Book.find({ isPublished: true }).select('_id updatedAt');
        books.forEach(book => {
            xml += \`  <url>\\n    <loc>\${HOST}/checkout?bookId=\${book._id}</loc>\\n    <lastmod>\${(book.updatedAt || new Date()).toISOString()}</lastmod>\\n    <changefreq>weekly</changefreq>\\n    <priority>0.9</priority>\\n  </url>\\n\`;
        });

        // 3. Close the XML tag
        xml += '</urlset>';

        // Send the response with correct Content-Type format
        res.header('Content-Type', 'application/xml');
        res.send(xml);
    } catch (error) {
        console.error('[Sitemap] Failed to generate sitemap:', error);
        res.status(500).end();
    }
});

// Routes
const multer = require('multer');

const { put } = require('@vercel/blob');`;

lines.splice(330, 18, replacement);
fs.writeFileSync('server.js', lines.join('\n'));

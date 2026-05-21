const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const svgContent = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
    <g transform="translate(0, 10)">
        <!-- Curved lines behind the V -->
        <path d="M 126 390 Q 206 120 256 150" fill="none" stroke="#00c885" stroke-width="16" stroke-linecap="round"/>
        <path d="M 176 390 Q 226 160 256 200" fill="none" stroke="#ff6b00" stroke-width="16" stroke-linecap="round"/>
        
        <path d="M 386 390 Q 306 120 256 150" fill="none" stroke="#ff6b00" stroke-width="16" stroke-linecap="round"/>
        <path d="M 336 390 Q 286 160 256 200" fill="none" stroke="#00c885" stroke-width="16" stroke-linecap="round"/>

        <!-- The White V -->
        <path d="M 156 180 L 256 360 L 356 180" fill="none" stroke="#ffffff" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>
        
        <!-- Colored Dots at the top tips -->
        <circle cx="156" cy="180" r="24" fill="#ff6b00" />
        <circle cx="356" cy="180" r="24" fill="#00c885" />
    </g>
</svg>
`;

// Save the SVG
fs.writeFileSync(path.join(__dirname, 'vylithra_mobile', 'assets', 'images', 'logo.svg'), svgContent);
fs.writeFileSync(path.join(__dirname, 'public', 'vylithra_logo.svg'), svgContent);

// Convert to high-res PNG
const svgBuffer = Buffer.from(svgContent);

async function generateLogos() {
    try {
        // Transparent high-res PNG for mobile app (Splash screen and launcher icon)
        await sharp(svgBuffer)
            .resize(1024, 1024, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
            .png()
            .toFile(path.join(__dirname, 'vylithra_mobile', 'assets', 'images', 'logo.png'));

        // Public logo
        await sharp(svgBuffer)
            .resize(1024, 1024, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
            .png()
            .toFile(path.join(__dirname, 'public', 'vylithra_logo.png'));
            
        // Icon for mobile
        await sharp(svgBuffer)
            .resize(1024, 1024, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
            .png()
            .toFile(path.join(__dirname, 'vylithra_mobile', 'assets', 'icon.png'));

        console.log('Successfully generated full HD transparent logos!');
    } catch (err) {
        console.error('Error generating logos:', err);
    }
}

generateLogos();

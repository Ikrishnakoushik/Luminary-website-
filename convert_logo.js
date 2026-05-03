const sharp = require('sharp');
const path = require('path');

const svgPath = path.join(__dirname, 'public', 'vylithra_logo.svg');
const pngPath = path.join(__dirname, 'public', 'vylithra_logo.png');

sharp(svgPath)
  .resize(1024, 1024, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }) // transparent bg
  .png()
  .toFile(pngPath)
  .then(() => console.log('Successfully converted SVG to PNG'))
  .catch(err => console.error('Error converting SVG to PNG:', err));

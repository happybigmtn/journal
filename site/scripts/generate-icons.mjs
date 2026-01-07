#!/usr/bin/env node
// Generate PWA icons from SVG source
import sharp from 'sharp';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const iconsDir = join(__dirname, '../public/icons');

// SVG source for the icon (inline for simplicity)
const svgSource = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="#000000"/>
  <rect x="96" y="64" width="320" height="384" fill="#FFFFFF"/>
  <line x1="128" y1="140" x2="384" y2="140" stroke="#E5E5E5" stroke-width="4"/>
  <line x1="128" y1="200" x2="384" y2="200" stroke="#E5E5E5" stroke-width="4"/>
  <line x1="128" y1="260" x2="384" y2="260" stroke="#E5E5E5" stroke-width="4"/>
  <line x1="128" y1="320" x2="384" y2="320" stroke="#E5E5E5" stroke-width="4"/>
  <line x1="128" y1="380" x2="320" y2="380" stroke="#E5E5E5" stroke-width="4"/>
  <path d="M400 120 L440 80 L460 100 L420 140 Z" fill="#000000"/>
  <path d="M380 140 L420 140 L380 180 Z" fill="#000000"/>
</svg>`;

const sizes = [192, 512];

async function generateIcons() {
  try {
    mkdirSync(iconsDir, { recursive: true });

    for (const size of sizes) {
      const outputPath = join(iconsDir, `icon-${size}.png`);
      await sharp(Buffer.from(svgSource))
        .resize(size, size)
        .png()
        .toFile(outputPath);
      console.log(`Generated: ${outputPath}`);
    }

    // Also generate apple-touch-icon
    const applePath = join(iconsDir, 'apple-touch-icon.png');
    await sharp(Buffer.from(svgSource))
      .resize(180, 180)
      .png()
      .toFile(applePath);
    console.log(`Generated: ${applePath}`);

    // Generate favicon
    const faviconPath = join(iconsDir, '../favicon.ico');
    await sharp(Buffer.from(svgSource))
      .resize(32, 32)
      .png()
      .toFile(faviconPath.replace('.ico', '.png'));
    console.log(`Generated: favicon.png`);

    console.log('All icons generated successfully!');
  } catch (error) {
    console.error('Error generating icons:', error);
    process.exit(1);
  }
}

generateIcons();

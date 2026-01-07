#!/bin/bash
# Publish journal site

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_DIR="$SCRIPT_DIR/../site"

cd "$SITE_DIR" || exit 1

echo "Building journal site..."
npm run build

if [ $? -eq 0 ]; then
    echo "Build successful!"

    # Optional: Deploy to GitHub Pages
    # Uncomment the following lines if using gh-pages
    # npm install -D gh-pages
    # npx gh-pages -d dist

    # Optional: Git commit and push
    # cd ..
    # git add .
    # git commit -m "Journal update $(date +%Y-%m-%d)"
    # git push

    echo "Site built to: $SITE_DIR/dist"
else
    echo "Build failed!"
    exit 1
fi

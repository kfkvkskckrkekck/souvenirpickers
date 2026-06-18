#!/bin/bash

echo "🚀 Deploying to souvenirpickers.com..."
echo ""

# Check if netlify CLI exists
if ! command -v netlify &> /dev/null; then
    echo "Installing Netlify CLI..."
    npm install -g netlify-cli
fi

echo "Deploying..."
netlify deploy --prod --dir=dist

echo ""
echo "✅ Done! Check https://souvenirpickers.com"
echo "Test auth at: https://souvenirpickers.com/test-auth-live.html"

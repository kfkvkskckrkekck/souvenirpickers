#!/bin/bash

# Quick Deploy Script Using Netlify Token
# This script deploys your site using the token from .env

set -e

echo "🚀 Deploying to Netlify..."
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep NETLIFY_AUTH_TOKEN | xargs)
    export $(cat .env | grep NETLIFY_SITE_ID | xargs)
else
    echo "❌ Error: .env file not found"
    exit 1
fi

# Check if token exists
if [ -z "$NETLIFY_AUTH_TOKEN" ]; then
    echo "❌ Error: NETLIFY_AUTH_TOKEN not found in .env"
    echo ""
    echo "Get a new token from:"
    echo "https://app.netlify.com/user/applications/personal"
    echo ""
    echo "Then add to .env:"
    echo "NETLIFY_AUTH_TOKEN=your_token_here"
    exit 1
fi

# Check if site ID exists
if [ -z "$NETLIFY_SITE_ID" ]; then
    echo "⚠️  Warning: NETLIFY_SITE_ID not found in .env"
    NETLIFY_SITE_ID="4b0690b0-7d5e-46aa-9d2a-531524ae8c2c"
    echo "Using default: $NETLIFY_SITE_ID"
fi

echo "📦 Building project..."
npm run build

echo ""
echo "🚀 Deploying to Netlify..."
echo "Site ID: $NETLIFY_SITE_ID"
echo ""

npx netlify-cli deploy \
    --prod \
    --dir=dist \
    --site=$NETLIFY_SITE_ID \
    --auth=$NETLIFY_AUTH_TOKEN

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Your site: https://souvenirpickers.netlify.app"
echo "Custom domain: https://souvenirpickers.com"
echo ""

#!/bin/bash

echo "🚀 LiveSouvenir Automated Deployment"
echo "====================================="
echo ""

# Check if Netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "❌ Netlify CLI not found!"
    echo ""
    echo "Please install it first:"
    echo "npm install -g netlify-cli"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ Netlify CLI found!"
echo ""

# Build the project
echo "📦 Building project..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Build failed! Please fix the errors and try again."
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Check if already logged in to Netlify
if ! netlify status &> /dev/null; then
    echo "🔑 Please log in to Netlify..."
    netlify login
fi

echo ""
echo "🚀 Deploying to Netlify..."
echo ""

# Deploy
netlify deploy --prod --dir=dist

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

echo ""
echo "✅ Deployment successful!"
echo ""
echo "⚠️  IMPORTANT: Add environment variables to Netlify:"
echo ""
echo "1. Go to your site settings in Netlify"
echo "2. Navigate to: Site configuration → Environment variables"
echo "3. Add these three variables:"
echo ""
echo "   VITE_SUPABASE_URL"
echo "   https://bfqvzxczmvfteqbhgyvx.supabase.co"
echo ""
echo "   VITE_SUPABASE_ANON_KEY"
echo "   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMyNDc2ODcsImV4cCI6MjA0ODgyMzY4N30.GzCdHjV_LKHFEWJkN_yYbvxhYFoROSz3w0qH3dEPyWo"
echo ""
echo "   VITE_STRIPE_PUBLISHABLE_KEY"
echo "   pk_live_51SI5wQFlPbAiVNx2hO266AapZfZLrCQZZOShtSjw3X4U0A7VyzRgMSBEx81psE24t7rnAU4CQVQc3uFoEniyFe4g00HbtBusTH"
echo ""
echo "4. After adding variables, redeploy from Netlify dashboard"
echo ""
echo "✨ Done!"

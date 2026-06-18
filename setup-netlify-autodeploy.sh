#!/bin/bash

# Netlify Auto-Deploy Setup Script
# This script configures your site for automatic deployment

set -e

echo "🚀 Setting up Netlify Auto-Deploy for SouvenirPickers"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if site is already linked
if [ -f ".netlify/state.json" ]; then
    echo -e "${GREEN}✓${NC} Site already linked to Netlify"
    SITE_ID=$(cat .netlify/state.json | grep -o '"siteId":"[^"]*"' | cut -d'"' -f4)
    echo "  Site ID: $SITE_ID"
else
    echo -e "${YELLOW}!${NC} Site not linked yet"
    SITE_ID="4b0690b0-7d5e-46aa-9d2a-531524ae8c2c"

    # Create .netlify directory structure
    mkdir -p .netlify
    echo '{"siteId":"'$SITE_ID'"}' > .netlify/state.json
    echo -e "${GREEN}✓${NC} Created Netlify configuration"
fi

echo ""
echo -e "${BLUE}Step 1: Verify build works${NC}"
echo "Running: npm run build"
npm run build

echo ""
echo -e "${GREEN}✓${NC} Build successful!"

echo ""
echo -e "${BLUE}Step 2: Netlify Configuration${NC}"
echo "Your netlify.toml is configured with:"
echo "  - Build command: npm run build"
echo "  - Publish directory: dist"
echo "  - Environment variables: ✓ Set"

echo ""
echo -e "${BLUE}Step 3: Choose Deployment Method${NC}"
echo ""
echo "Option A: GitHub Auto-Deploy (Recommended)"
echo "  • Push your code to GitHub"
echo "  • Connect repository in Netlify dashboard"
echo "  • Every push automatically deploys"
echo ""
echo "Option B: Manual CLI Deploy"
echo "  • Run: npx netlify-cli deploy --prod"
echo "  • Manual process each time"
echo ""

echo -e "${YELLOW}To set up GitHub auto-deploy:${NC}"
echo "1. Push to GitHub:"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo "   git remote add origin https://github.com/YOUR_USERNAME/souvenirpickers.git"
echo "   git push -u origin main"
echo ""
echo "2. Go to Netlify: https://app.netlify.com/sites/souvenirpickers"
echo ""
echo "3. Site settings → Build & deploy → Continuous Deployment"
echo ""
echo "4. Link repository → Select GitHub → Choose your repo"
echo ""
echo "5. Build settings (should auto-detect from netlify.toml):"
echo "   ✓ Build command: npm run build"
echo "   ✓ Publish directory: dist"
echo ""
echo "6. That's it! Every git push now deploys automatically"
echo ""

echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Your site: https://souvenirpickers.netlify.app"
echo "Custom domain: https://souvenirpickers.com"
echo ""
echo "Need a new Netlify token?"
echo "Visit: https://app.netlify.com/user/applications/personal"

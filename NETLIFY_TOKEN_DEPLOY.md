# 🔑 Netlify Token-Based Auto-Deploy Setup

Your Netlify site is ready for automatic deployment using authentication tokens.

**Site ID**: `4b0690b0-7d5e-46aa-9d2a-531524ae8c2c`

---

## 🎯 Quick Start (3 Options)

### Option 1: GitHub Auto-Deploy ⭐ RECOMMENDED

This is the easiest method - every `git push` automatically deploys your site.

#### Step 1: Get a Fresh Netlify Token

Your current token appears to be expired. Get a new one:

1. Go to: https://app.netlify.com/user/applications/personal
2. Click "New access token"
3. Name: `souvenirpickers-deploy`
4. Click "Generate token"
5. **Copy the token immediately** (shown only once)

#### Step 2: Update Your .env File

Replace the old token in `.env`:
```bash
NETLIFY_AUTH_TOKEN=YOUR_NEW_TOKEN_HERE
```

#### Step 3: Link GitHub Repository

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Set your token
export NETLIFY_AUTH_TOKEN=YOUR_NEW_TOKEN_HERE

# Link to existing site
npx netlify-cli link --id 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c

# Deploy once manually to test
npx netlify-cli deploy --prod
```

#### Step 4: Connect GitHub in Netlify Dashboard

1. Go to: https://app.netlify.com/sites/souvenirpickers/settings/deploys
2. Click "Link repository"
3. Choose "GitHub"
4. Select your `souvenirpickers` repository
5. Configure:
   - Branch: `main`
   - Build command: `npm run build` (auto-detected from netlify.toml)
   - Publish directory: `dist` (auto-detected from netlify.toml)
6. Click "Save"

**Done!** Every `git push` now auto-deploys 🎉

---

### Option 2: Direct Netlify CLI Deploy

For manual deployments without GitHub:

```bash
# Set your Netlify token
export NETLIFY_AUTH_TOKEN=YOUR_NEW_TOKEN

# Deploy to production
npx netlify-cli deploy --prod --site 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c
```

---

### Option 3: Use Netlify Dashboard (No Token Needed)

1. Go to: https://app.netlify.com/
2. Log in with your account
3. Find your site (ID: 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c)
4. Go to: Deploys → Deploy settings
5. Click "Link repository"
6. Follow the GitHub connection wizard

---

## 🔧 Automated Deploy Script

I've created `setup-netlify-autodeploy.sh` for you:

```bash
./setup-netlify-autodeploy.sh
```

This will:
- ✅ Test your build
- ✅ Configure Netlify settings
- ✅ Guide you through GitHub connection

---

## 📦 What's Already Configured

Your `netlify.toml` has everything set up:

✅ **Build Settings**
- Command: `npm run build`
- Publish directory: `dist`
- Node version: 18

✅ **Environment Variables**
- VITE_SUPABASE_URL
- VITE_SUPABASE_ANON_KEY
- VITE_STRIPE_PUBLISHABLE_KEY

✅ **Redirects**
- www → non-www redirect
- SPA fallback to index.html

✅ **Security Headers**
- X-Frame-Options
- X-XSS-Protection
- Content Security Policy
- Cache-Control

✅ **Performance**
- Asset caching (1 year)
- Service worker no-cache

---

## 🚀 Deploy Now

### Using CLI with Token:

```bash
# Export your token
export NETLIFY_AUTH_TOKEN=nfp_YOUR_NEW_TOKEN_HERE

# Build and deploy
npm run build
npx netlify-cli deploy --prod --dir=dist --site=4b0690b0-7d5e-46aa-9d2a-531524ae8c2c
```

### Using GitHub Push:

```bash
# Commit your changes
git add .
git commit -m "Deploy to production"

# Push to GitHub (triggers auto-deploy)
git push origin main
```

---

## 🔐 Environment Variables

All environment variables are configured in `netlify.toml`. No need to add them manually in the Netlify dashboard!

If you need to add more:

```bash
# Using CLI
npx netlify-cli env:set VARIABLE_NAME "value" --site 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c

# Or in dashboard
# https://app.netlify.com/sites/souvenirpickers/settings/env
```

---

## ✅ Verify Deployment

After deploying, test:

1. **Site is live**: https://souvenirpickers.netlify.app
2. **Custom domain**: https://souvenirpickers.com
3. **Authentication**: Try login/signup
4. **Supabase**: Check database queries work
5. **Stripe**: Test payments

---

## 🔄 How Auto-Deploy Works

Once GitHub is connected:

1. You push code: `git push origin main`
2. Netlify detects the push
3. Runs: `npm run build`
4. Deploys `dist/` folder
5. Site updates (2-3 minutes)

---

## 🛠 Troubleshooting

### Token Unauthorized Error

Your token expired. Get a new one:
- https://app.netlify.com/user/applications/personal

### Build Fails

Check build logs in Netlify dashboard:
- https://app.netlify.com/sites/souvenirpickers/deploys

Common issues:
- Environment variables not set
- Node version mismatch
- Dependency installation failed

### Site Not Loading

1. Check DNS configuration
2. Verify environment variables
3. Check browser console for errors
4. Review Netlify function logs

---

## 📊 Monitor Deployments

View all deployments:
- https://app.netlify.com/sites/souvenirpickers/deploys

Features:
- Deploy history
- Build logs
- Rollback to previous versions
- Deploy previews for PRs
- Deploy notifications

---

## 🎉 You're All Set!

Your site is configured for automatic deployment. Choose your preferred method and start deploying!

**Next Steps**:
1. Get a fresh Netlify token (if using CLI)
2. Connect GitHub repository (for auto-deploy)
3. Push your code
4. Watch it deploy automatically!

**Site URL**: https://souvenirpickers.com
**Netlify Dashboard**: https://app.netlify.com/sites/souvenirpickers

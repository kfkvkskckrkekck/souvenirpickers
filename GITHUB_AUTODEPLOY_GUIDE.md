# 🚀 GitHub Auto-Deploy Setup Guide

Set up automatic deployment so every `git push` deploys your site instantly!

---

## ⚡ Quick Setup (10 minutes)

### Step 1: Push Code to GitHub (5 min)

```bash
# Initialize git repository
git init

# Add all files
git add .

# Create first commit
git commit -m "Initial commit - SouvenirPickers marketplace"

# Create a new repository on GitHub
# Go to: https://github.com/new
# Repository name: souvenirpickers
# Make it Private or Public (your choice)
# DON'T initialize with README

# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/souvenirpickers.git

# Push to GitHub
git push -u origin main
```

---

### Step 2: Connect GitHub to Netlify (5 min)

#### Option A: Through Netlify Dashboard (Easiest)

1. **Go to Netlify**
   - Visit: https://app.netlify.com/
   - Log in to your account

2. **Find Your Site**
   - Your site ID: `4b0690b0-7d5e-46aa-9d2a-531524ae8c2c`
   - Or search for: "souvenirpickers"

3. **Link Repository**
   - Go to: **Site settings** → **Build & deploy** → **Continuous Deployment**
   - Click: **Link repository**
   - Choose: **GitHub**
   - Click: **Authorize Netlify** (if needed)

4. **Select Repository**
   - Find: `YOUR_USERNAME/souvenirpickers`
   - Click to select it

5. **Configure Build Settings**

   These should auto-detect from `netlify.toml`:

   ```
   Base directory: (leave empty)
   Build command: npm run build
   Publish directory: dist
   Branch: main
   ```

6. **Review Environment Variables**

   Already configured in `netlify.toml`:
   - ✅ VITE_SUPABASE_URL
   - ✅ VITE_SUPABASE_ANON_KEY
   - ✅ VITE_STRIPE_PUBLISHABLE_KEY
   - ✅ NODE_VERSION

7. **Save and Deploy**
   - Click: **Save**
   - First deploy starts automatically
   - Watch the build logs

---

#### Option B: Using Netlify CLI

If you prefer command line:

```bash
# Get a fresh token
# Visit: https://app.netlify.com/user/applications/personal

# Export token
export NETLIFY_AUTH_TOKEN=your_token_here

# Link your site
npx netlify-cli link --id 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c

# Set up continuous deployment
npx netlify-cli api updateSite \
    --data '{"repo": {"provider": "github", "repo": "YOUR_USERNAME/souvenirpickers"}}'
```

---

## ✅ Verify Auto-Deploy Works

### Test the Setup:

1. **Make a small change**
   ```bash
   # Edit a file (like README.md)
   echo "# SouvenirPickers" > README.md

   # Commit the change
   git add README.md
   git commit -m "Test auto-deploy"

   # Push to GitHub
   git push origin main
   ```

2. **Watch it Deploy**
   - Go to: https://app.netlify.com/sites/souvenirpickers/deploys
   - You should see a new deploy start automatically
   - Takes 2-3 minutes

3. **Check the Live Site**
   - Visit: https://souvenirpickers.com
   - Your change should be live!

---

## 🎯 How It Works

```
You: git push origin main
          ↓
    GitHub receives push
          ↓
    Netlify webhook triggered
          ↓
    Netlify clones your repo
          ↓
    Runs: npm install
          ↓
    Runs: npm run build
          ↓
    Deploys dist/ folder
          ↓
    Site live in ~2-3 minutes
```

---

## 🔧 Advanced Features

### Deploy Previews

Every pull request gets its own preview URL!

1. Create a branch: `git checkout -b feature-name`
2. Push changes: `git push origin feature-name`
3. Open PR on GitHub
4. Netlify comments with preview URL
5. Test before merging!

### Branch Deploys

Deploy different branches to different URLs:

- `main` → https://souvenirpickers.com (production)
- `staging` → https://staging--souvenirpickers.netlify.app
- `dev` → https://dev--souvenirpickers.netlify.app

Configure in: **Site settings** → **Build & deploy** → **Deploy contexts**

### Build Hooks

Trigger deployments from anywhere:

1. Go to: **Site settings** → **Build & deploy** → **Build hooks**
2. Click: **Add build hook**
3. Name: "Manual Deploy"
4. Branch: main
5. Get webhook URL

Deploy with:
```bash
curl -X POST -d {} https://api.netlify.com/build_hooks/YOUR_HOOK_ID
```

---

## 📊 Monitor Deployments

### Netlify Dashboard

View everything at: https://app.netlify.com/sites/souvenirpickers

Features:
- 📈 Deploy history and logs
- 🔄 One-click rollbacks
- 📧 Deploy notifications (email/Slack)
- 🔍 Build performance analytics
- 🚨 Failed deploy alerts

### Deploy Notifications

Set up notifications:

1. Go to: **Site settings** → **Build & deploy** → **Deploy notifications**
2. Add integrations:
   - Email notifications
   - Slack messages
   - GitHub commit statuses
   - Webhooks to your own services

---

## 🛠 Useful Commands

### View deploy status:
```bash
npx netlify-cli status
```

### View deploy logs:
```bash
npx netlify-cli watch
```

### Open site in browser:
```bash
npx netlify-cli open:site
```

### Open admin dashboard:
```bash
npx netlify-cli open:admin
```

### Manual deploy:
```bash
npm run build
npx netlify-cli deploy --prod
```

---

## 🚨 Troubleshooting

### Deploy Not Triggering

**Check webhook:**
1. GitHub repo → Settings → Webhooks
2. Look for Netlify webhook
3. Check recent deliveries
4. Re-deliver if needed

**Verify in Netlify:**
1. Site settings → Build & deploy
2. Ensure "Auto publishing" is enabled
3. Check "Deploy contexts" settings

### Build Failing

**Check build logs:**
- https://app.netlify.com/sites/souvenirpickers/deploys

**Common issues:**
- Missing environment variables
- Node version mismatch (set NODE_VERSION=18)
- npm install failures (clear cache)
- Build command errors (verify locally)

**Clear cache and retry:**
1. Go to failed deploy
2. Click "Options" → "Clear cache and retry"

### Wrong Environment Variables

**Update in Netlify:**
1. Site settings → Environment variables
2. Edit or add variables
3. Trigger new deploy

**Or update netlify.toml:**
```toml
[build.environment]
  NEW_VARIABLE = "value"
```

---

## 🎉 You're Done!

Your site now auto-deploys on every push!

**Workflow:**
```bash
# Make changes
vim src/components/MyComponent.tsx

# Commit
git add .
git commit -m "Update component"

# Push (triggers auto-deploy)
git push origin main

# ☕ Grab coffee while it deploys (~2 min)
# 🎉 Site is live!
```

---

## 📚 Next Steps

- ✅ Set up deploy notifications
- ✅ Configure deploy previews for PRs
- ✅ Create staging branch
- ✅ Add custom domain (souvenirpickers.com)
- ✅ Enable branch deploys
- ✅ Set up Slack notifications

**Your Sites:**
- Production: https://souvenirpickers.com
- Netlify URL: https://souvenirpickers.netlify.app
- Dashboard: https://app.netlify.com/sites/souvenirpickers

Happy deploying! 🚀

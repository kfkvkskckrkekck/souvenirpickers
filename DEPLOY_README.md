# 🚀 Netlify Auto-Deploy - Quick Start

Your SouvenirPickers marketplace is ready for automatic deployment!

---

## 🎯 Choose Your Method

### Method 1: GitHub Auto-Deploy ⭐ RECOMMENDED

**Best for:** Automatic deployment on every push

**Setup time:** 10 minutes

**What you get:**
- ✅ Auto-deploy on `git push`
- ✅ Deploy previews for PRs
- ✅ Easy rollbacks
- ✅ Build history

**Follow:** `GITHUB_AUTODEPLOY_GUIDE.md`

---

### Method 2: Token-Based Deploy

**Best for:** Manual deployments, CI/CD pipelines

**Setup time:** 5 minutes

**What you get:**
- ✅ Deploy from command line
- ✅ Use in scripts/automation
- ✅ No GitHub needed

**Follow:** `NETLIFY_TOKEN_DEPLOY.md`

**Quick deploy:**
```bash
./deploy-with-token.sh
```

---

## ⚡ Super Quick Start

### If you want GitHub auto-deploy:

```bash
# 1. Push to GitHub
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/souvenirpickers.git
git push -u origin main

# 2. Connect on Netlify
# Go to: https://app.netlify.com/sites/souvenirpickers
# Link your GitHub repository
# Done! Every push now deploys automatically
```

### If you want manual deploy with token:

```bash
# 1. Get new token
# Visit: https://app.netlify.com/user/applications/personal
# Copy token

# 2. Update .env
# NETLIFY_AUTH_TOKEN=your_new_token

# 3. Deploy
./deploy-with-token.sh
```

---

## 📁 Files Created for You

| File | Purpose |
|------|---------|
| `GITHUB_AUTODEPLOY_GUIDE.md` | Complete GitHub integration guide |
| `NETLIFY_TOKEN_DEPLOY.md` | Token-based deployment guide |
| `QUICK_DEPLOY_CHECKLIST.md` | 5-minute checklist |
| `get-netlify-token.md` | How to get a fresh token |
| `deploy-with-token.sh` | One-command deploy script |
| `setup-netlify-autodeploy.sh` | Interactive setup script |
| `netlify.toml` | Build configuration (already set up) |

---

## ✅ What's Already Configured

Your `netlify.toml` has everything:

✅ **Build Settings**
- Command: `npm run build`
- Directory: `dist`
- Node: v18

✅ **Environment Variables**
- Supabase URL & keys
- Stripe publishable key

✅ **Redirects**
- www → non-www
- SPA routing

✅ **Security Headers**
- XSS Protection
- Content Security
- Frame Options

✅ **Performance**
- Asset caching
- Compression

---

## 🎯 Your Site Information

**Site ID:** `4b0690b0-7d5e-46aa-9d2a-531524ae8c2c`

**URLs:**
- Production: https://souvenirpickers.com
- Netlify: https://souvenirpickers.netlify.app
- Dashboard: https://app.netlify.com/sites/souvenirpickers

---

## 🔧 Quick Commands

### Build locally:
```bash
npm run build
```

### Deploy with token:
```bash
./deploy-with-token.sh
```

### Setup GitHub auto-deploy:
```bash
./setup-netlify-autodeploy.sh
```

### Check deploy status:
```bash
npx netlify-cli status
```

---

## 🆘 Need Help?

### Token expired?
See: `get-netlify-token.md`

### Want GitHub auto-deploy?
See: `GITHUB_AUTODEPLOY_GUIDE.md`

### Build failing?
```bash
# Test locally first
npm run build

# Check logs in Netlify
# https://app.netlify.com/sites/souvenirpickers/deploys
```

### Environment variables?
Already configured in `netlify.toml` ✅

---

## 🎉 Ready to Deploy!

Pick your method and start deploying:

1. **GitHub Auto-Deploy** → Follow `GITHUB_AUTODEPLOY_GUIDE.md`
2. **Token Deploy** → Run `./deploy-with-token.sh`

Either way, your site will be live at:
**https://souvenirpickers.com**

Happy deploying! 🚀

# ✅ Quick Netlify Deploy Checklist

## Before You Start
- [ ] Code is ready and tested
- [ ] Build runs successfully (`npm run build`)
- [ ] You have a GitHub account

---

## 🚀 5-Minute Setup

### 1️⃣ Push to GitHub (5 minutes)
```bash
git init
git add .
git commit -m "Ready for deployment"
git remote add origin https://github.com/YOUR_USERNAME/souvenirpickers.git
git push -u origin main
```

### 2️⃣ Connect to Netlify (2 minutes)
1. Go to https://app.netlify.com/
2. Click "Add new site" → "Import from GitHub"
3. Select your `souvenirpickers` repository

### 3️⃣ Configure Build (1 minute)
- Build command: `npm run build`
- Publish directory: `dist`
- Branch: `main`

### 4️⃣ Add Environment Variables (2 minutes)
Copy-paste these in Netlify:

```
VITE_SUPABASE_URL=https://bfqvzxczmvfteqbhgyvx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MTAxODIsImV4cCI6MjA3OTk4NjE4Mn0.2kgZ_VfgN42cs3B-40snDRgThCOVNIJ0BGQ_gdhbzy0
VITE_STRIPE_PUBLISHABLE_KEY=pk_live_51SI5wQFlPbAiVNx2hO266AapZfZLrCQZZOShtSjw3X4U0A7VyzRgMSBEx81psE24t7rnAU4CQVQc3uFoEniyFe4g00HbtBusTH
NODE_VERSION=18
```

### 5️⃣ Deploy (automatic)
- Click "Deploy site"
- Wait 2-3 minutes
- Done!

---

## 🌐 Add Custom Domain (Optional)

### In Netlify:
1. Site settings → Domain management
2. Add domain: `souvenirpickers.com`
3. Add alias: `www.souvenirpickers.com`

### In Bluehost DNS:
```
A Record:
  Host: @
  Points to: 75.2.60.5

CNAME Record:
  Host: www
  Points to: [your-site].netlify.app
```

---

## 🎯 Result

After setup, every `git push` automatically deploys your site!

**Your Netlify Site ID**: `4b0690b0-7d5e-46aa-9d2a-531524ae8c2c`

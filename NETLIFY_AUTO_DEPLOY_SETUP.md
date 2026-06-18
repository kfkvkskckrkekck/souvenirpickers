# 🚀 Netlify Auto-Deploy Setup Guide

Your project is ready for automatic deployment! Follow these steps to connect your GitHub repository to Netlify.

---

## ✅ Prerequisites

Your project already has:
- ✅ `netlify.toml` configured
- ✅ Build scripts working
- ✅ Environment variables documented
- ✅ Netlify Site ID: `4b0690b0-7d5e-46aa-9d2a-531524ae8c2c`

---

## 📋 Step-by-Step Setup

### Step 1: Push Your Code to GitHub

If you haven't already pushed your code to GitHub:

```bash
# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit changes
git commit -m "Initial commit - SouvenirPickers marketplace"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Push to GitHub
git push -u origin main
```

---

### Step 2: Connect GitHub to Netlify

1. **Go to Netlify Dashboard**
   - Visit: https://app.netlify.com/
   - Log in with your account

2. **Import Existing Project**
   - Click "Add new site" → "Import an existing project"
   - Choose "Deploy with GitHub"

3. **Authorize GitHub**
   - Click "Authorize Netlify"
   - Grant access to your repository

4. **Select Repository**
   - Find and select your `souvenirpickers` repository
   - Click on it to continue

5. **Configure Build Settings**
   - **Site name**: `souvenirpickers` (or your preferred name)
   - **Branch to deploy**: `main`
   - **Build command**: `npm run build`
   - **Publish directory**: `dist`
   - Click "Show advanced" to add environment variables

---

### Step 3: Add Environment Variables in Netlify

Click "New variable" and add these **EXACT** variables:

| Variable Name | Value |
|--------------|-------|
| `VITE_SUPABASE_URL` | `https://bfqvzxczmvfteqbhgyvx.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MTAxODIsImV4cCI6MjA3OTk4NjE4Mn0.2kgZ_VfgN42cs3B-40snDRgThCOVNIJ0BGQ_gdhbzy0` |
| `VITE_STRIPE_PUBLISHABLE_KEY` | `pk_live_51SI5wQFlPbAiVNx2hO266AapZfZLrCQZZOShtSjw3X4U0A7VyzRgMSBEx81psE24t7rnAU4CQVQc3uFoEniyFe4g00HbtBusTH` |
| `NODE_VERSION` | `18` |

**⚠️ Important**: DO NOT add SMTP credentials to Netlify - those are only for Supabase Edge Functions.

---

### Step 4: Deploy Your Site

1. Click **"Deploy site"**
2. Netlify will:
   - Clone your repository
   - Install dependencies with `npm install`
   - Run `npm run build`
   - Publish the `dist` folder

3. **Wait for deployment** (usually 2-3 minutes)
   - Watch the build logs in real-time
   - You'll see "Site is live" when complete

---

### Step 5: Set Up Custom Domain (souvenirpickers.com)

1. **In Netlify Dashboard**:
   - Go to "Site settings" → "Domain management"
   - Click "Add custom domain"
   - Enter: `souvenirpickers.com`
   - Click "Verify"

2. **Add www subdomain**:
   - Click "Add domain alias"
   - Enter: `www.souvenirpickers.com`

3. **Configure DNS at Bluehost**:

   Go to Bluehost → Domains → DNS Management and add these records:

   **A Record (for souvenirpickers.com)**:
   ```
   Type: A
   Host: @
   Points to: 75.2.60.5
   TTL: Automatic
   ```

   **CNAME Record (for www)**:
   ```
   Type: CNAME
   Host: www
   Points to: [your-site-name].netlify.app
   TTL: Automatic
   ```

4. **Enable HTTPS**:
   - In Netlify: Domain settings → HTTPS
   - Click "Verify DNS configuration"
   - Click "Provision certificate" (automatic & free)

---

## 🎯 What Happens After Setup

Once connected, **every time you push to GitHub**:

1. ✅ Netlify automatically detects the push
2. ✅ Runs `npm run build`
3. ✅ Deploys the new version
4. ✅ Your site updates in ~2 minutes

---

## 🔄 Manual Deploy (Alternative)

If you prefer to deploy without GitHub:

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login to Netlify
netlify login

# Deploy
netlify deploy --prod
```

---

## 🧪 Test Your Deployment

After deployment, verify:

1. **Site is live**: Visit your Netlify URL
2. **Authentication works**: Try signup/login
3. **Supabase connection**: Check database queries work
4. **Stripe payments**: Test payment processing
5. **Custom domain**: Visit souvenirpickers.com

---

## 📊 Monitor Deployments

In your Netlify dashboard you can:
- View deployment history
- See build logs
- Roll back to previous versions
- Set up deploy notifications
- Monitor site analytics

---

## 🆘 Troubleshooting

### Build Fails

Check the build logs in Netlify. Common issues:
- Missing environment variables
- Node version mismatch (ensure NODE_VERSION=18)
- Failed npm install (clear cache in Deploy settings)

### Site Not Loading

- Check DNS propagation (can take up to 48 hours)
- Verify environment variables are set correctly
- Check browser console for errors

### Supabase Errors

- Verify VITE_SUPABASE_URL matches your project
- Check VITE_SUPABASE_ANON_KEY is correct
- Ensure RLS policies allow access

---

## 🎉 You're All Set!

Your site will now automatically deploy whenever you push changes to GitHub.

**Next Steps**:
1. Push your code to GitHub
2. Connect repository in Netlify
3. Add environment variables
4. Deploy!

**Need Help?**
- Netlify Docs: https://docs.netlify.com
- Support: https://answers.netlify.com

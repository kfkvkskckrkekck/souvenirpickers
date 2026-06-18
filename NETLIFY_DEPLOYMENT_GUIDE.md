# Netlify Deployment Guide for SouvenirPickers

## Quick Start - Deploy Now!

Your app is **100% ready to deploy**! Follow these steps:

### 1. Connect to Netlify

**Option A: Deploy via Netlify UI (Recommended)**
1. Go to [netlify.com](https://netlify.com) and sign in
2. Click "Add new site" → "Import an existing project"
3. Connect your Git provider (GitHub, GitLab, or Bitbucket)
4. Select your `souvenirpickers` repository
5. Netlify will auto-detect settings from `netlify.toml`
6. Click "Deploy site"

**Option B: Deploy via Netlify CLI**
```bash
# Install Netlify CLI globally
npm install -g netlify-cli

# Login to Netlify
netlify login

# Deploy from project root
netlify deploy --prod
```

### 2. Domain Setup (souvenirpickers.com)

Your `CNAME` file is already configured for `souvenirpickers.com`.

**In Netlify Dashboard:**
1. Go to Site settings → Domain management
2. Click "Add custom domain"
3. Enter: `souvenirpickers.com`
4. Follow Netlify's instructions to configure DNS

**DNS Records Needed:**
```
Type: A
Name: @
Value: 75.2.60.5 (Netlify's load balancer)

Type: CNAME
Name: www
Value: [your-site-name].netlify.app
```

### 3. Environment Variables

**Already Configured!** ✅

Your environment variables are set in `netlify.toml`:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_STRIPE_PUBLISHABLE_KEY`

These will automatically be used during the build.

### 4. Post-Deployment Checklist

After your first deployment:

**✅ Verify Supabase Connection**
- Test user registration/login
- Verify database operations work

**✅ Test Stripe Payments**
- Complete a test transaction
- Verify webhooks are receiving events
- Check Stripe Dashboard for successful payments

**✅ Update Stripe Webhook URL**
In your Stripe Dashboard:
1. Go to Developers → Webhooks
2. Add endpoint: `https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook`
3. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`

**✅ Update Supabase Edge Functions**
Update allowed origins in your Edge Functions if needed:
```typescript
const corsHeaders = {
  "Access-Control-Allow-Origin": "https://souvenirpickers.com",
  // ... other headers
};
```

**✅ Test Core Features**
- User authentication (signup/login/logout)
- Profile creation and updates
- Listing creation by Pickers
- Order placement by Collectors
- Payment processing
- Real-time chat
- Notifications
- File uploads (images/videos)

---

## Build Configuration

Your `netlify.toml` is already optimized with:

### Build Settings
```toml
[build]
  publish = "dist"          # Vite output directory
  command = "npm run build"  # Build command

[build.environment]
  NODE_VERSION = "18"        # Node.js version
```

### Performance Optimizations
- SPA redirects for React Router
- Security headers (XSS, Frame Options, etc.)
- Aggressive caching for assets (1 year)
- No caching for service worker
- CORS headers configured

### Current Build Output
```
dist/index.html                            8.29 kB
dist/assets/index-FM9TtNHA.css            69.72 kB
dist/assets/supabase-vendor-BOsFIl5i.js  125.87 kB
dist/assets/react-vendor-CQW2wFTC.js     141.32 kB
dist/assets/index-BTmpB658.js            643.71 kB
Total: ~988 kB (minified)
```

---

## Netlify Deploy Challenge Steps

To complete the Netlify Deploy Challenge:

### Step 1: Create Netlify Account
Go to netlify.com and sign up if you haven't already.

### Step 2: Connect Repository
- Click "Add new site"
- Choose your Git provider
- Authorize Netlify to access your repositories
- Select the `souvenirpickers` repository

### Step 3: Configure Build Settings
Netlify will auto-detect from `netlify.toml`:
- **Build command:** `npm run build`
- **Publish directory:** `dist`
- **Node version:** 18

Click "Deploy site" - no additional configuration needed!

### Step 4: Wait for Deployment
- First build typically takes 2-5 minutes
- Watch the deploy log for any issues
- Once complete, you'll get a URL like `random-name-123.netlify.app`

### Step 5: Verify Deployment
Visit your deployed site and test:
- Homepage loads
- Can navigate between pages
- Can sign up / log in
- Can view listings

### Step 6: Add Custom Domain (Optional)
- Go to Domain settings
- Add `souvenirpickers.com`
- Configure DNS as instructed
- Enable HTTPS (automatic with Netlify)

### Step 7: Claim Your Prize! 🎉
Once deployed successfully, you've completed the challenge!

---

## Troubleshooting

### Build Fails
Check the deploy logs in Netlify dashboard for specific errors.

**Common issues:**
- Missing dependencies: Run `npm install` locally
- Type errors: Run `npm run typecheck`
- Build errors: Run `npm run build` locally

### Environment Variables Not Working
Double-check they're set in `netlify.toml` under `[build.environment]`.

### Stripe Webhooks Failing
- Verify webhook URL is correct
- Check Stripe signing secret is set in Supabase Edge Functions
- Test webhook with Stripe CLI:
  ```bash
  stripe listen --forward-to https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook
  ```

### 404 Errors on Page Refresh
Already handled! The redirect rule in `netlify.toml` ensures all routes go to `index.html`.

### Slow Load Times
The bundle is 643 kB. Consider code-splitting if needed, but this is reasonable for a full-featured marketplace app.

---

## Security Notes

**Production Keys in Use:**
- ✅ Live Stripe publishable key configured
- ✅ Supabase anon key (safe for client-side)
- ✅ Security headers enabled
- ✅ HTTPS enforced by Netlify

**Secrets NOT in Repository:**
- ❌ Stripe secret key (stored in Supabase Edge Functions)
- ❌ Supabase service role key (stored in Supabase)

---

## Support Resources

- **Netlify Docs:** [docs.netlify.com](https://docs.netlify.com)
- **Netlify Status:** [netlifystatus.com](https://netlifystatus.com)
- **Deploy Logs:** Available in Netlify dashboard under "Deploys"
- **Community:** [community.netlify.com](https://community.netlify.com)

---

## Next Steps After Deployment

1. **Monitor Performance**
   - Use Netlify Analytics (paid feature)
   - Or integrate Google Analytics

2. **Set Up Continuous Deployment**
   - Every push to main branch auto-deploys
   - Create staging branch for testing

3. **Enable Deploy Previews**
   - Automatic preview URLs for pull requests
   - Test changes before merging

4. **Configure Notifications**
   - Get notified of successful/failed deploys
   - Set up in Netlify dashboard

5. **Optimize Further**
   - Consider Netlify Image CDN for photos
   - Enable Asset Optimization in Netlify

---

**Your SouvenirPickers marketplace is production-ready! 🚀**

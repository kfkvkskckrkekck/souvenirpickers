# Netlify Deploy Challenge - Quick Checklist ✅

## Pre-Deployment (Already Done! ✅)

- [x] Build succeeds (`npm run build`)
- [x] `netlify.toml` configured
- [x] Environment variables set
- [x] CNAME file configured for souvenirpickers.com
- [x] Security headers configured
- [x] SPA redirects configured
- [x] Production Stripe keys configured
- [x] Supabase connection configured

## Deployment Steps

### 1. Connect to Netlify (5 minutes)
- [ ] Go to [netlify.com](https://netlify.com)
- [ ] Sign in or create account
- [ ] Click "Add new site" → "Import an existing project"
- [ ] Connect your Git provider
- [ ] Select `souvenirpickers` repository
- [ ] Click "Deploy site" (settings auto-detected)

### 2. First Deployment (2-5 minutes)
- [ ] Wait for build to complete
- [ ] Check deploy logs for errors
- [ ] Visit the provided `.netlify.app` URL
- [ ] Test that site loads correctly

### 3. Custom Domain Setup (10 minutes)
- [ ] In Netlify: Site settings → Domain management
- [ ] Add custom domain: `souvenirpickers.com`
- [ ] Configure DNS records:
  ```
  A Record:     @ → 75.2.60.5
  CNAME Record: www → [your-site].netlify.app
  ```
- [ ] Wait for DNS propagation (can take up to 24 hours)
- [ ] SSL certificate auto-provisions (Netlify handles this)

### 4. Post-Deployment Testing (15 minutes)
- [ ] Test homepage loads
- [ ] Test user registration
- [ ] Test user login
- [ ] Test viewing listings
- [ ] Test creating a listing (Picker role)
- [ ] Test placing an order (Collector role)
- [ ] Test payment flow
- [ ] Test chat functionality
- [ ] Test notifications
- [ ] Test profile updates

### 5. Configure Production Integrations

**Stripe Webhooks:**
- [ ] Go to Stripe Dashboard → Developers → Webhooks
- [ ] Add endpoint: `https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook`
- [ ] Select events: `payment_intent.*`, `checkout.session.*`, `customer.subscription.*`
- [ ] Copy webhook signing secret
- [ ] Add to Supabase Edge Functions secrets as `STRIPE_WEBHOOK_SECRET`

**Supabase (Already Configured):**
- [x] Database schema deployed
- [x] RLS policies active
- [x] Edge Functions deployed
- [x] Storage buckets configured

### 6. Claim Your Prize! 🎉
- [ ] Verify site is live at souvenirpickers.com
- [ ] Complete Netlify Deploy Challenge
- [ ] Celebrate! 🎊

---

## Quick Deploy Commands

### Option 1: Netlify CLI
```bash
npm install -g netlify-cli
netlify login
netlify deploy --prod
```

### Option 2: Git Push (Continuous Deployment)
```bash
git add .
git commit -m "Ready for production"
git push origin main
```
(Netlify auto-deploys after connecting repository)

---

## Important URLs

- **Live Site:** https://souvenirpickers.com (after DNS)
- **Netlify Dashboard:** https://app.netlify.com
- **Supabase Dashboard:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx
- **Stripe Dashboard:** https://dashboard.stripe.com

---

## Need Help?

See detailed instructions in `NETLIFY_DEPLOYMENT_GUIDE.md`

---

**You're ready to deploy! Good luck with the challenge! 🚀**

# Domain Migration to souvenirpickers.com - Setup Guide

## What You Need to Do

### 1. DNS Configuration (Required)
Point your domain to your hosting provider:

**For Netlify:**
- Go to your domain registrar (GoDaddy, Namecheap, etc.)
- Add these DNS records:
  ```
  Type: A
  Name: @
  Value: 75.2.60.5

  Type: CNAME
  Name: www
  Value: [your-netlify-site].netlify.app
  ```

**Or use Netlify DNS:**
- Transfer your nameservers to Netlify's DNS
- Netlify will provide you with nameserver addresses

### 2. Netlify Domain Configuration (Required)
- Go to Netlify Dashboard > Your Site > Domain Settings
- Click "Add custom domain"
- Enter: `souvenirpickers.com`
- Click "Verify" and "Add domain"
- Netlify will automatically provision SSL certificate (takes 10-60 minutes)

### 3. Supabase Edge Functions - Update Stripe Secret (Critical)
- Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/functions
- Add/Update this secret:
  ```
  Key: STRIPE_SECRET_KEY
  Value: sk_live_51SI5wQFlPbAiVNx2[YOUR_LIVE_SECRET_KEY]
  ```

### 4. Stripe Webhook Configuration (Critical for Payments)
- Go to: https://dashboard.stripe.com/webhooks
- Add new endpoint: `https://souvenirpickers.com/functions/v1/stripe-webhook`
- Select events:
  - payment_intent.succeeded
  - payment_intent.payment_failed
  - customer.subscription.created
  - customer.subscription.updated
  - customer.subscription.deleted
- Copy the webhook signing secret
- Add to Supabase secrets:
  ```
  Key: STRIPE_WEBHOOK_SECRET
  Value: whsec_[YOUR_WEBHOOK_SECRET]
  ```

### 5. Supabase Auth Configuration
- Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration
- Add to "Redirect URLs":
  - `https://souvenirpickers.com`
  - `https://souvenirpickers.com/**`
- Add to "Site URL": `https://souvenirpickers.com`

### 6. Deploy to Netlify
Push your code or trigger a new build in Netlify to deploy with the updated configuration.

## Verification Steps

### Check DNS Propagation
```bash
nslookup souvenirpickers.com
dig souvenirpickers.com
```

### Check SSL Certificate
Visit: `https://souvenirpickers.com` (should show secure padlock)

### Test Auth Flow
1. Try signing up / logging in
2. Check password reset emails have correct links

### Test Payment Flow
1. Try making a test purchase
2. Verify Stripe webhook receives events
3. Check order confirmation emails

## Common Issues

**"Domain not found"**
- DNS records not configured or not propagated yet (can take 24-48 hours)

**"Not secure" / SSL error**
- SSL certificate not provisioned yet (wait 10-60 minutes after adding domain to Netlify)

**Payments failing**
- Stripe webhook not configured
- STRIPE_SECRET_KEY not set in Supabase
- Using test keys instead of live keys

**Email links broken**
- Supabase redirect URLs not updated
- Magic link recovery not configured

## Need Help?

If you're stuck, tell me which step is failing and I can help troubleshoot!

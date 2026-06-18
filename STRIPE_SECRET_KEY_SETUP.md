# Fix Stripe Payment Method Error

## Problem
You're getting "No such PaymentMethod" error because:
- Frontend is using a LIVE Stripe key: `pk_live_51SI8fZLXfVhH6CM0...`
- Backend doesn't have the matching SECRET key configured

## Solution: Add Stripe Secret Key to Supabase

### Step 1: Get Your Stripe Secret Key
1. Go to https://dashboard.stripe.com/apikeys
2. Find your **Secret key** that matches your publishable key
   - Since you're using `pk_live_...`, you need the **LIVE secret key**: `sk_live_...`
   - **IMPORTANT**: Use the SAME mode (test or live) for both keys!

### Step 2: Add Secret Key to Supabase
1. Go to your Supabase dashboard: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx
2. Click on **Edge Functions** in the left sidebar
3. Click on **Secrets**
4. Click **Add secret**
5. Add:
   - Name: `STRIPE_SECRET_KEY`
   - Value: Your secret key (starts with `sk_live_` or `sk_test_`)
6. Click **Save**

### Step 3: Restart Edge Functions (Automatic)
The edge functions will automatically pick up the new secret. No redeployment needed!

### Step 4: Test Again
Go back to your app and try adding a card again. It should work now!

## Key/Mode Matching

Make sure both keys are from the SAME mode:

### Test Mode (for testing)
- Frontend: `pk_test_...`
- Backend: `sk_test_...`

### Live Mode (for production)
- Frontend: `pk_live_...`
- Backend: `sk_live_...`

Your current setup shows you're using LIVE mode, so make sure to use your LIVE secret key.

## Security Note
- Never commit secret keys to your code
- Keep them in Supabase Secrets only
- The publishable key in `.env` is safe to commit (it's public)

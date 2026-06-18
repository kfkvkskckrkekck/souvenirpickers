# Stripe Setup Guide for LiveSouvenir Subscriptions

This guide will help you set up Stripe to collect real subscription payments from Pickers.

## Overview

- **Pickers pay**: €1/month after 60-day free trial
- **Collectors**: Free (no subscription)
- **Payment Method**: Credit/Debit cards via Stripe

## Step 1: Create a Stripe Account

1. Go to https://stripe.com and click "Start now"
2. Fill out your business information
3. Complete the verification process

## Step 2: Get Your Stripe API Keys

1. Log in to your Stripe Dashboard: https://dashboard.stripe.com
2. Navigate to **Developers** → **API keys**
3. You'll see two types of keys:
   - **Publishable key** (starts with `pk_`): Used in your frontend
   - **Secret key** (starts with `sk_`): Used in your backend (KEEP THIS PRIVATE!)

### For Testing (Test Mode)
- Use keys that start with `pk_test_` and `sk_test_`
- No real money is charged

### For Production (Live Mode)
- Toggle to "Live mode" in the Stripe Dashboard
- Use keys that start with `pk_live_` and `sk_live_`
- Real money will be charged

## Step 3: Configure Environment Variables

### Local .env file

Add your Stripe keys to `.env`:

```bash
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key_here
```

### Supabase Environment Variables

The Edge Functions need your Stripe secret key. Set it in Supabase:

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** → **Edge Functions** → **Secrets**
4. Add a new secret:
   - Name: `STRIPE_SECRET_KEY`
   - Value: `sk_test_your_secret_key_here` (or `sk_live_` for production)

## Step 4: Test the Integration

### Test Cards

Use these test card numbers in TEST MODE:

| Card Number | Description |
|-------------|-------------|
| 4242 4242 4242 4242 | Successful payment |
| 4000 0000 0000 9995 | Payment declined (insufficient funds) |
| 4000 0025 0000 3155 | Requires authentication (3D Secure) |

- Use any future expiry date (e.g., 12/25)
- Use any 3-digit CVV (e.g., 123)
- Use any valid billing address

### Testing Flow

1. Create a Picker account
2. Go to Profile → Add Payment Method
3. Enter test card: 4242 4242 4242 4242
4. Save the payment method
5. The system will automatically charge €1/month after 60 days

## Step 5: Monitor Payments

### Stripe Dashboard

View all subscription payments:
1. Go to https://dashboard.stripe.com/payments
2. See successful charges, failed payments, and more

### In Your Database

Query subscription payments:
```sql
SELECT * FROM picker_subscription_payments
ORDER BY created_at DESC;
```

## Step 6: Go Live

When ready for production:

1. Complete Stripe account verification
2. Switch to Live mode in Stripe Dashboard
3. Get your LIVE API keys (pk_live_ and sk_live_)
4. Update environment variables with live keys
5. Test with a real card (you can refund test charges)

## How Subscription Billing Works

1. **Trial Period**: Pickers get 60 days free
2. **Trial End**: System automatically charges €1.00
3. **Monthly Billing**: Every 30 days, €1.00 is charged
4. **Payment Failure**: Picker is notified and given 7 days to update payment method
5. **Account Suspension**: If payment fails after 7 days, account is suspended

## Automated Billing Schedule

The system checks daily for subscriptions that need to be charged:
- Runs automatically via `process-monthly-subscriptions` Edge Function
- You can also trigger it manually for testing

## Important Security Notes

⚠️ **NEVER commit your secret keys to Git!**
⚠️ **Keep sk_test_ and sk_live_ keys private**
⚠️ **Only use pk_* keys in frontend code**

## Support

- Stripe Documentation: https://stripe.com/docs
- Stripe Support: https://support.stripe.com
- Test Card Numbers: https://stripe.com/docs/testing

## Webhook Setup (Optional but Recommended)

To receive real-time notifications about payment events:

1. Go to Stripe Dashboard → **Developers** → **Webhooks**
2. Click "Add endpoint"
3. Enter your webhook URL: `https://your-project.supabase.co/functions/v1/stripe-webhook`
4. Select events: `payment_intent.succeeded`, `payment_intent.failed`
5. Copy the webhook signing secret (starts with `whsec_`)
6. Add to Supabase secrets as `STRIPE_WEBHOOK_SECRET`

## Cost Breakdown

Stripe fees:
- 2.9% + €0.30 per successful charge
- For a €1.00 subscription: You receive ~€0.67 per month per picker

Example:
- 100 pickers × €1.00 = €100/month revenue
- Stripe fees: ~€33/month
- Your net: ~€67/month

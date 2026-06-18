# Quick Start: Collecting Subscription Payments

## What You Need to Do Now

### 1. Create a Stripe Account (5 minutes)

1. Go to https://stripe.com
2. Click "Start now" and create your account
3. Complete basic business information

### 2. Get Your Stripe API Keys (2 minutes)

1. Log in to Stripe Dashboard: https://dashboard.stripe.com
2. Go to **Developers** → **API keys**
3. Copy your keys:
   - **Publishable key**: `pk_test_...` (for testing) or `pk_live_...` (for production)
   - **Secret key**: `sk_test_...` (for testing) or `sk_live_...` (for production)

### 3. Add Keys to Your Project (3 minutes)

#### A. Update .env file (for frontend)

Edit `/project/.env` and replace:
```bash
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE
```

#### B. Add secret to Supabase (for backend)

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx
2. Click **Settings** → **Edge Functions** → **Secrets**
3. Click "Add new secret"
4. Enter:
   - Name: `STRIPE_SECRET_KEY`
   - Value: `sk_test_YOUR_SECRET_KEY_HERE`
5. Click "Save"

### 4. Deploy Edge Functions (2 minutes)

You need to deploy 3 Edge Functions to Supabase. I've created them at:
- `supabase/functions/save-payment-method/`
- `supabase/functions/process-subscription-payment/`
- `supabase/functions/process-monthly-subscriptions/`

These functions will automatically charge subscriptions and collect payments.

### 5. Test It! (5 minutes)

1. Restart your dev server (if running)
2. Sign up as a Picker
3. Go to Profile → Edit Profile
4. Scroll to "Payment Methods" section
5. Click "Add Payment Method"
6. Use test card: **4242 4242 4242 4242**
   - Expiry: Any future date (e.g., 12/25)
   - CVV: Any 3 digits (e.g., 123)
7. Click "Save Payment Method"

## How Payments Work

### For Pickers:
1. **60-day free trial** starts when they sign up
2. After trial ends, **€1.00 charged monthly**
3. Pickers add payment card in Profile → Payment Methods
4. Card is charged automatically every 30 days

### For Collectors:
- **100% FREE** - no subscription needed
- They only pay for souvenirs they order

### Payment Processing:
1. `process-monthly-subscriptions` Edge Function runs daily
2. Checks which Pickers need to be charged
3. Charges €1.00 to their saved payment method
4. Records payment in database
5. Sends notification to Picker

## Viewing Collected Payments

### In Stripe Dashboard:
- Go to https://dashboard.stripe.com/payments
- See all charges, successful and failed

### In Your Database:
```sql
-- View all subscription payments
SELECT * FROM picker_subscription_payments
ORDER BY created_at DESC;

-- View total revenue
SELECT
  SUM(amount) as total_revenue,
  COUNT(*) as total_payments
FROM picker_subscription_payments
WHERE payment_status = 'succeeded';

-- View monthly revenue
SELECT
  DATE_TRUNC('month', paid_at) as month,
  SUM(amount) as monthly_revenue,
  COUNT(*) as payment_count
FROM picker_subscription_payments
WHERE payment_status = 'succeeded'
GROUP BY month
ORDER BY month DESC;
```

## Test Cards (TEST MODE ONLY)

| Card Number | Result |
|-------------|--------|
| 4242 4242 4242 4242 | Success |
| 4000 0000 0000 9995 | Declined (insufficient funds) |
| 4000 0000 0000 0077 | Declined (expired card) |

## Important Stripe Fees

- **Per transaction**: 2.9% + €0.30
- **For €1.00 subscription**: You receive ~€0.67 (Stripe keeps ~€0.33)
- **For 100 pickers**: €100 revenue, you keep ~€67

## Going Live (When Ready)

1. Complete Stripe account verification
2. Switch to "Live mode" in Stripe Dashboard
3. Get LIVE keys (pk_live_... and sk_live_...)
4. Update .env with `pk_live_...`
5. Update Supabase secret with `sk_live_...`
6. Test with a real card (you can refund it)

## Monthly Billing Automation

The system automatically charges subscriptions:
- Edge Function: `process-monthly-subscriptions`
- Runs: Daily (checks for due subscriptions)
- Charges: €1.00 per picker every 30 days
- Handles: Payment failures, notifications, retries

## Troubleshooting

**"Stripe is not configured"**
- Make sure you added STRIPE_SECRET_KEY to Supabase secrets
- Make sure you updated VITE_STRIPE_PUBLISHABLE_KEY in .env

**"Payment failed"**
- In test mode, use test card 4242 4242 4242 4242
- Check Stripe Dashboard for error details
- Make sure Edge Functions are deployed

**"Edge Function not found"**
- Deploy the Edge Functions to Supabase
- Check function names match exactly

## Support

- Full guide: See STRIPE_SETUP_GUIDE.md
- Stripe docs: https://stripe.com/docs
- Stripe support: https://support.stripe.com

## Next Steps

After setup is complete:
1. ✅ Test with test cards
2. ✅ Verify payments appear in Stripe Dashboard
3. ✅ Check database for payment records
4. ✅ Test automated monthly billing
5. ✅ When ready, switch to Live mode

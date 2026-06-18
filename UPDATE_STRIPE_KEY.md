# Update Stripe Secret Key

## New Test Mode Secret Key
```
nfp_X2tMgimqfRxjvQEnqsbuCNjBhJwcHEC8a3c7
```

## How to Update in Supabase

### Option 1: Via Supabase Dashboard (Recommended)

1. Go to your Supabase project dashboard at:
   https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx

2. Navigate to **Edge Functions** in the left sidebar

3. Click on **Secrets** or **Environment Variables**

4. Find `STRIPE_SECRET_KEY` in the list

5. Click **Edit** or the pencil icon next to it

6. Replace the value with:
   ```
   nfp_X2tMgimqfRxjvQEnqsbuCNjBhJwcHEC8a3c7
   ```

7. Click **Save** or **Update**

8. **IMPORTANT**: Redeploy all Edge Functions that use Stripe
   - The secrets are only updated in deployed functions after redeployment
   - Functions using Stripe:
     - `process-picker-payout`
     - `process-referral-payout`
     - `create-payment-intent`
     - `stripe-webhook`
     - `process-subscription-payment`
     - `create-stripe-subscription`
     - And others...

### Option 2: Via Supabase CLI

If you have the Supabase CLI installed:

```bash
supabase secrets set STRIPE_SECRET_KEY=nfp_X2tMgimqfRxjvQEnqsbuCNjBhJwcHEC8a3c7
```

Then redeploy the affected Edge Functions.

## What This Key Is Used For

This Stripe secret key is used across multiple Edge Functions for:

1. **Payment Processing**
   - Creating payment intents
   - Processing subscription payments
   - Handling cart checkouts

2. **Payout Processing**
   - Transferring funds to pickers
   - Processing referral bonuses
   - Automatic escrow releases

3. **Stripe Connect**
   - Creating Express accounts for pickers
   - Managing connected accounts
   - Processing transfers

4. **Webhook Handling**
   - Verifying webhook signatures
   - Processing payment events
   - Handling account updates

## Test Mode vs Live Mode

The new key you provided (`nfp_X2t...`) is a **TEST MODE** key, which means:

- ✅ Safe for development and testing
- ✅ No real money will be charged
- ✅ Use test card numbers (e.g., 4242 4242 4242 4242)
- ❌ Cannot process real payments
- ❌ Cannot connect real bank accounts

### Test Card Numbers

When testing with this key, use:
```
Card Number: 4242 4242 4242 4242
Expiry: Any future date (e.g., 12/25)
CVC: Any 3 digits (e.g., 123)
ZIP: Any 5 digits (e.g., 12345)
```

## Important Notes

1. **Secret Keys Are Server-Side Only**
   - This key should NEVER be exposed in frontend code
   - It's only used in Edge Functions (server-side)
   - The `.env` file only contains the public Supabase keys

2. **Webhook Secret**
   - You also have `STRIPE_WEBHOOK_SECRET` configured
   - Make sure it matches your Stripe webhook endpoint
   - Find it in Stripe Dashboard → Developers → Webhooks

3. **After Updating**
   - Test the payment flow end-to-end
   - Verify pickers can receive payouts
   - Check that subscriptions work
   - Test the cart checkout process

## Verification

After updating the secret, verify it's working by:

1. **Test a Payment**
   - Add an item to cart
   - Complete checkout with test card
   - Check if order is created

2. **Test Payout**
   - Create an order
   - Mark as delivered
   - Check if payout processes correctly

3. **Check Edge Function Logs**
   - Go to Edge Functions → Select function → Logs
   - Look for any Stripe-related errors

## Need Help?

If you encounter issues:
- Check Edge Function logs for error messages
- Verify the secret key is set correctly
- Ensure all functions are redeployed
- Test with Stripe's test card numbers

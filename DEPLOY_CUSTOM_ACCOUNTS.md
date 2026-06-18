# Deploy Custom Stripe Connect Accounts to Production

## What Changed

Your platform now uses **Custom Stripe Connect accounts** instead of Express accounts. This means:
- No more "Restricted" status
- No Stripe redirects for pickers
- They just enter bank details and start receiving payments
- Platform automatically deducts 10% commission

## When Will Restriction Be Removed?

**IMMEDIATELY** after you deploy and pickers use the new bank linking form. Here's why:

**Old System (Express Accounts):**
- Created accounts in "Restricted" status
- Required onboarding via Stripe redirect
- Stayed restricted until user completed Stripe's forms

**New System (Custom Accounts):**
- Creates accounts with full permissions immediately
- No onboarding required
- Account is active as soon as bank is linked

## Deploy to Production

### Step 1: Deploy Frontend to Netlify

```bash
# Build the production bundle
npm run build

# Deploy to Netlify
npx netlify-cli deploy --prod --dir=dist
```

Or use Netlify web dashboard:
1. Go to https://app.netlify.com
2. Select your site: souvenirpickers.com
3. Drag and drop the `dist` folder
4. Wait for deployment to complete

### Step 2: Verify Edge Function is Deployed

The `link-bank-to-stripe` function has already been deployed to Supabase. Verify:

1. Go to https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/functions
2. Confirm `link-bank-to-stripe` is listed and deployed

### Step 3: Clean Up Old Express Accounts (Optional)

If you have existing Express accounts in "Restricted" status:

1. Go to Stripe Dashboard: https://dashboard.stripe.com/connect/accounts
2. Delete the old restricted accounts
3. Let pickers re-enter their bank details using the new system
4. New Custom accounts will be created automatically

### Step 4: Test the Flow

1. Go to https://souvenirpickers.com
2. Log in as a picker
3. Navigate to Payout Setup
4. Fill in bank details:
   - Bank name
   - Account holder name
   - Account number (IBAN)
   - SWIFT code
   - Personal info (name, DOB, address)
5. Click Save
6. You should see: "Bank account linked successfully! Platform will retain 10% commission, and you will receive 90% of payments."

### Step 5: Verify in Stripe Dashboard

1. Go to https://dashboard.stripe.com/connect/accounts
2. You should see a new **Custom** account (not Express)
3. Status should be **Active** (not Restricted)
4. Payouts enabled: **Yes**

## Testing Payouts

To test the full flow:

1. **Create a test order** with a picker who has linked their bank
2. **Process payment** from collector (use test card `4242424242424242`)
3. **Confirm delivery** as the collector
4. **Check payout**:
   - Go to Stripe Dashboard > Balance > Transfers
   - You should see a transfer for 90% of the order amount
   - Platform kept 10% automatically

## Production Checklist

Before going live with real money:

- [ ] Deploy frontend to Netlify
- [ ] Verify `link-bank-to-stripe` function is deployed on Supabase
- [ ] Test with Stripe test mode first
- [ ] Switch to Stripe live mode
- [ ] Update `STRIPE_SECRET_KEY` in Supabase secrets with **live** key
- [ ] Test complete flow with real bank account (use small amount)
- [ ] Monitor first few payouts in Stripe dashboard
- [ ] Set up Stripe webhooks for automatic notifications

## Key Differences You'll Notice

**Before (Express Accounts):**
```
Picker clicks "Setup Payout"
→ Redirects to Stripe
→ Fills forms on Stripe
→ Gets "Restricted" status
→ Waits for approval
```

**After (Custom Accounts):**
```
Picker clicks "Setup Payout"
→ Fills form in your app
→ Clicks Save
→ Account active immediately
→ Ready to receive payments
```

## Monitoring Payouts

View all activity in Stripe Dashboard:

- **Connect > Accounts**: All picker Custom accounts
- **Balance > Transfers**: All payouts to pickers (90% of order)
- **Balance > Balance**: Your platform balance (10% commission)
- **Reports**: Download CSV of all transactions

## Need Help?

If you see any errors:
1. Check browser console for error messages
2. Check Supabase Edge Function logs
3. Check Stripe Dashboard > Developers > Logs
4. Verify all environment variables are set correctly

Your platform is now ready for production with direct bank linking and automatic commission deduction.
